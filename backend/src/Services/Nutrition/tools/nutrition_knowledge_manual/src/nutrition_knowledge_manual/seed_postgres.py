from __future__ import annotations

import base64
import csv
import io
import json
from pathlib import Path
import subprocess
from typing import Any

from .errors import ManualGraphError
from .seed_chunks import _validated_chunks

_DATABASE_GUARD = """DO $$ BEGIN
 IF current_database() <> 'nutrition'
    OR to_regclass('nutrition.knowledge_sources') IS NULL
    OR to_regclass('nutrition.knowledge_chunks') IS NULL THEN
  RAISE EXCEPTION 'Expected migrated Nutrition knowledge database';
 END IF;
END $$;
"""


def _source_row(source: dict[str, Any], chunks_sha256: str, count: int) -> dict[str, Any]:
    return {
        "source_revision_id": source["revision_id"], "source_id": source["source_id"],
        "title": source["title"], "source_sha256": source["sha256"],
        "chunks_sha256": chunks_sha256, "rights_status": source["rights_status"],
        "chunk_count": count,
    }


def _chunk_row(chunk: dict[str, Any]) -> dict[str, Any]:
    return {
        "chunk_id": chunk["chunk_id"], "source_revision_id": chunk["source_revision_id"],
        "pdf_page": chunk["pdf_page"], "printed_page": chunk.get("printed_page"),
        "ordinal_on_page": chunk["chunk_ordinal_on_page"], "content_type": chunk["content_type"],
        "review_status": chunk["review_status"], "index_eligible": chunk["index_eligible"],
        "token_count": chunk["token_count"], "headings": chunk["headings"],
        "content": chunk["text"], "text_sha256": chunk["text_sha256"],
    }


def _copy_json_rows(rows: list[dict[str, Any]]) -> str:
    buffer = io.StringIO(newline="")
    writer = csv.writer(buffer, lineterminator="\n", quoting=csv.QUOTE_ALL)
    for row in rows:
        writer.writerow([json.dumps(row, ensure_ascii=False, separators=(",", ":"), sort_keys=True)])
    return buffer.getvalue() + "\\.\n"


def build_seed_sql(
    *, source: dict[str, Any], chunks: list[dict[str, Any]], chunks_sha256: str
) -> str:
    """Build one atomic, idempotent PostgreSQL import from validated PDF chunks."""
    count = len(chunks)
    # All source values travel as COPY data, including titles containing SQL delimiters.
    source_data = _copy_json_rows([_source_row(source, chunks_sha256, count)])
    chunk_data = _copy_json_rows([_chunk_row(chunk) for chunk in chunks])
    return f"""BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '60s';
{_DATABASE_GUARD}
CREATE TEMP TABLE knowledge_import_source (payload jsonb NOT NULL) ON COMMIT DROP;
COPY knowledge_import_source(payload) FROM STDIN WITH (FORMAT csv);
{source_data}
SELECT pg_advisory_xact_lock(hashtext(payload->>'source_revision_id')) FROM knowledge_import_source;
CREATE TEMP TABLE knowledge_import (payload jsonb NOT NULL) ON COMMIT DROP;
COPY knowledge_import(payload) FROM STDIN WITH (FORMAT csv);
{chunk_data}
DO $$ BEGIN
 IF (SELECT count(*) FROM knowledge_import) <> {count} THEN
  RAISE EXCEPTION 'Knowledge import row count mismatch';
 END IF;
END $$;
INSERT INTO nutrition.knowledge_sources
 (source_revision_id,source_id,title,source_sha256,chunks_sha256,rights_status,chunk_count)
 SELECT payload->>'source_revision_id',payload->>'source_id',payload->>'title',
  payload->>'source_sha256',payload->>'chunks_sha256',payload->>'rights_status',
  (payload->>'chunk_count')::integer FROM knowledge_import_source
 ON CONFLICT (source_revision_id) DO NOTHING;
DO $$ BEGIN
 IF EXISTS (
  SELECT 1 FROM knowledge_import_source i
  LEFT JOIN nutrition.knowledge_sources s ON s.source_revision_id=i.payload->>'source_revision_id'
  WHERE (to_jsonb(s)-'imported_at') IS DISTINCT FROM i.payload
 ) THEN RAISE EXCEPTION 'Existing knowledge source revision differs from input'; END IF;
END $$;
INSERT INTO nutrition.knowledge_chunks
 (chunk_id,source_revision_id,pdf_page,printed_page,ordinal_on_page,
  content_type,review_status,index_eligible,token_count,headings,content,text_sha256)
SELECT payload->>'chunk_id', payload->>'source_revision_id', (payload->>'pdf_page')::integer,
 payload->>'printed_page', (payload->>'ordinal_on_page')::integer,
 payload->>'content_type', payload->>'review_status',
 (payload->>'index_eligible')::boolean, (payload->>'token_count')::integer,
 payload->'headings', payload->>'content', payload->>'text_sha256'
FROM knowledge_import
ON CONFLICT (chunk_id) DO NOTHING;
DO $$ BEGIN
 IF (SELECT count(*) FROM nutrition.knowledge_chunks
     WHERE source_revision_id=(SELECT payload->>'source_revision_id' FROM knowledge_import_source)) <> {count}
  OR EXISTS (
   SELECT 1 FROM knowledge_import i
   LEFT JOIN nutrition.knowledge_chunks c ON c.chunk_id=i.payload->>'chunk_id'
   WHERE to_jsonb(c) IS DISTINCT FROM i.payload
  ) THEN RAISE EXCEPTION 'Seeded knowledge chunks differ from verified input'; END IF;
END $$;
SELECT 'SEED_RESULT|' || count(*) || '|' || count(*) FILTER (WHERE index_eligible)
 || '|' || count(*) FILTER (WHERE review_status='manual_review_required')
FROM nutrition.knowledge_chunks
WHERE source_revision_id=(SELECT payload->>'source_revision_id' FROM knowledge_import_source);
COMMIT;
"""


def _run_postgres(script: str, container: str, database_user: str) -> str:
    if not container or not database_user:
        raise ManualGraphError("PostgreSQL container and user are required")
    try:
        process = subprocess.run(
            ["docker", "exec", "-i", "-e", "PGCLIENTENCODING=UTF8", container,
             "psql", "-X", "-w", "-qAt", "-v", "ON_ERROR_STOP=1",
             "-U", database_user, "-d", "nutrition"],
            input=script, text=True, encoding="utf-8", capture_output=True, check=False,
            timeout=120,
        )
    except subprocess.TimeoutExpired as error:
        raise ManualGraphError("PostgreSQL knowledge operation timed out") from error
    except OSError as error:
        raise ManualGraphError("Could not start the local PostgreSQL client") from error
    if process.returncode != 0:
        # psql errors may include COPY data; keep source text out of ordinary logs.
        raise ManualGraphError(f"PostgreSQL knowledge operation failed (exit code {process.returncode})")
    return process.stdout


def _summary(source: dict[str, Any], chunks: list[dict[str, Any]], chunks_sha256: str,
             container: str, status: str) -> dict[str, Any]:
    return {
        "status": status, "database": "nutrition", "container": container,
        "source_revision_id": source["revision_id"], "chunk_count": len(chunks),
        "index_eligible_count": sum(bool(chunk["index_eligible"]) for chunk in chunks),
        "manual_review_count": sum(chunk["review_status"] == "manual_review_required" for chunk in chunks),
        "chunks_sha256": chunks_sha256,
    }


def seed_postgres_chunks(
    *, source: dict[str, Any], chunks_path: Path, report_path: Path,
    container: str, database_user: str
) -> dict[str, Any]:
    chunks, chunks_sha256 = _validated_chunks(
        source=source, chunks_path=chunks_path, report_path=report_path
    )
    script = build_seed_sql(source=source, chunks=chunks, chunks_sha256=chunks_sha256)
    output = _run_postgres(script, container, database_user)
    marker = next(
        (line for line in output.splitlines() if line.startswith("SEED_RESULT|")), None
    )
    expected = (
        f"SEED_RESULT|{len(chunks)}|"
        f"{sum(bool(chunk['index_eligible']) for chunk in chunks)}|"
        f"{sum(chunk['review_status'] == 'manual_review_required' for chunk in chunks)}"
    )
    if marker != expected:
        raise ManualGraphError("PostgreSQL knowledge seed verification returned unexpected counts")
    return _summary(source, chunks, chunks_sha256, container, "seeded_and_verified")


def verify_postgres_chunks(
    *, source: dict[str, Any], chunks_path: Path, report_path: Path,
    container: str, database_user: str
) -> dict[str, Any]:
    """Compare every stored field with the validated source in a read-only snapshot."""
    chunks, chunks_sha256 = _validated_chunks(
        source=source, chunks_path=chunks_path, report_path=report_path
    )
    encoded_revision = base64.b64encode(source["revision_id"].encode("utf-8")).decode("ascii")
    revision_sql = f"convert_from(decode('{encoded_revision}','base64'),'UTF8')"
    script = f"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '60s';
{_DATABASE_GUARD}
SELECT jsonb_build_object(
 'source', (SELECT to_jsonb(s)-'imported_at' FROM nutrition.knowledge_sources s
            WHERE source_revision_id={revision_sql}),
 'chunks', (SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY chunk_id),'[]'::jsonb)
            FROM nutrition.knowledge_chunks c WHERE source_revision_id={revision_sql})
);
COMMIT;
"""
    try:
        stored = json.loads(_run_postgres(script, container, database_user))
    except json.JSONDecodeError as error:
        raise ManualGraphError("PostgreSQL knowledge verification returned invalid JSON") from error
    if stored.get("source") != _source_row(source, chunks_sha256, len(chunks)):
        raise ManualGraphError("Stored knowledge source is missing or differs from verified input")
    expected = sorted((_chunk_row(chunk) for chunk in chunks), key=lambda row: row["chunk_id"])
    if stored.get("chunks") != expected:
        raise ManualGraphError("Stored knowledge chunks differ from verified input")
    return _summary(source, chunks, chunks_sha256, container, "verified_read_only")
