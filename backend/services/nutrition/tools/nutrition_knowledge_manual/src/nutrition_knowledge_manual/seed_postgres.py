from __future__ import annotations

import csv
import io
import json
from pathlib import Path
import subprocess
from typing import Any

from .errors import ManualGraphError
from .seed_chunks import _validated_chunks


def _literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build_seed_sql(
    *, source: dict[str, Any], chunks: list[dict[str, Any]], chunks_sha256: str
) -> str:
    """Build one atomic, idempotent PostgreSQL import from validated PDF chunks."""
    revision = _literal(source["revision_id"])
    source_id = _literal(source["source_id"])
    title = _literal(source["title"])
    source_sha256 = _literal(source["sha256"])
    chunks_digest = _literal(chunks_sha256)
    rights = _literal(source["rights_status"])
    count = len(chunks)

    csv_buffer = io.StringIO(newline="")
    writer = csv.writer(csv_buffer, lineterminator="\n", quoting=csv.QUOTE_ALL)
    for chunk in chunks:
        writer.writerow([json.dumps(chunk, ensure_ascii=False, separators=(",", ":"), sort_keys=True)])

    return f"""BEGIN;
DO $$ BEGIN
 IF current_database() <> 'nutrition'
    OR to_regclass('nutrition.knowledge_sources') IS NULL
    OR to_regclass('nutrition.knowledge_chunks') IS NULL THEN
  RAISE EXCEPTION 'Expected migrated Nutrition knowledge database';
 END IF;
END $$;
SELECT pg_advisory_xact_lock(hashtext({revision}));
CREATE TEMP TABLE knowledge_import (payload jsonb NOT NULL) ON COMMIT DROP;
COPY knowledge_import(payload) FROM STDIN WITH (FORMAT csv);
{csv_buffer.getvalue()}\\.
DO $$ BEGIN
 IF (SELECT count(*) FROM knowledge_import) <> {count} THEN
  RAISE EXCEPTION 'Knowledge import row count mismatch';
 END IF;
END $$;
INSERT INTO nutrition.knowledge_sources
 (source_revision_id,source_id,title,source_sha256,chunks_sha256,rights_status,chunk_count)
 VALUES ({revision},{source_id},{title},{source_sha256},{chunks_digest},{rights},{count})
 ON CONFLICT (source_revision_id) DO NOTHING;
DO $$ BEGIN
 IF NOT EXISTS (
  SELECT 1 FROM nutrition.knowledge_sources
  WHERE source_revision_id={revision} AND source_id={source_id}
   AND title={title} AND source_sha256={source_sha256}
   AND chunks_sha256={chunks_digest} AND rights_status={rights}
   AND chunk_count={count}
 ) THEN RAISE EXCEPTION 'Existing knowledge source revision differs from input'; END IF;
END $$;
INSERT INTO nutrition.knowledge_chunks
 (chunk_id,source_revision_id,pdf_page,printed_page,ordinal_on_page,
  content_type,review_status,index_eligible,token_count,headings,content,text_sha256)
SELECT payload->>'chunk_id', {revision}, (payload->>'pdf_page')::integer,
 payload->>'printed_page', (payload->>'chunk_ordinal_on_page')::integer,
 payload->>'content_type', payload->>'review_status',
 (payload->>'index_eligible')::boolean, (payload->>'token_count')::integer,
 payload->'headings', payload->>'text', payload->>'text_sha256'
FROM knowledge_import
ON CONFLICT (chunk_id) DO NOTHING;
DO $$ BEGIN
 IF (SELECT count(*) FROM nutrition.knowledge_chunks WHERE source_revision_id={revision}) <> {count}
  OR EXISTS (
   SELECT 1 FROM knowledge_import i
   LEFT JOIN nutrition.knowledge_chunks c ON c.chunk_id=i.payload->>'chunk_id'
   WHERE c.chunk_id IS NULL OR c.source_revision_id<>{revision}
    OR c.pdf_page<>(i.payload->>'pdf_page')::integer
    OR c.ordinal_on_page<>(i.payload->>'chunk_ordinal_on_page')::integer
    OR c.review_status<>i.payload->>'review_status'
    OR c.index_eligible<>(i.payload->>'index_eligible')::boolean
    OR c.token_count<>(i.payload->>'token_count')::integer
    OR c.content<>i.payload->>'text' OR c.text_sha256<>i.payload->>'text_sha256'
  ) THEN RAISE EXCEPTION 'Seeded knowledge chunks differ from verified input'; END IF;
END $$;
COMMIT;
SELECT 'SEED_RESULT|' || count(*) || '|' || count(*) FILTER (WHERE index_eligible)
 || '|' || count(*) FILTER (WHERE review_status='manual_review_required')
FROM nutrition.knowledge_chunks WHERE source_revision_id={revision};
"""


def seed_postgres_chunks(
    *, source: dict[str, Any], chunks_path: Path, report_path: Path,
    container: str, database_user: str
) -> dict[str, Any]:
    chunks, chunks_sha256 = _validated_chunks(
        source=source, chunks_path=chunks_path, report_path=report_path
    )
    if not container or not database_user:
        raise ManualGraphError("PostgreSQL container and user are required")
    script = build_seed_sql(source=source, chunks=chunks, chunks_sha256=chunks_sha256)
    try:
        process = subprocess.run(
            ["docker", "exec", "-i", container, "psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1",
             "-U", database_user, "-d", "nutrition"],
            input=script, text=True, encoding="utf-8", capture_output=True, check=False,
        )
    except OSError as error:
        raise ManualGraphError("Could not start the local PostgreSQL client") from error
    if process.returncode != 0:
        raise ManualGraphError(f"PostgreSQL knowledge seed failed (exit code {process.returncode})")
    marker = next(
        (line for line in process.stdout.splitlines() if line.startswith("SEED_RESULT|")), None
    )
    expected = (
        f"SEED_RESULT|{len(chunks)}|"
        f"{sum(bool(chunk['index_eligible']) for chunk in chunks)}|"
        f"{sum(chunk['review_status'] == 'manual_review_required' for chunk in chunks)}"
    )
    if marker != expected:
        raise ManualGraphError("PostgreSQL knowledge seed verification returned unexpected counts")
    return {
        "status": "seeded_and_verified",
        "database": "nutrition",
        "container": container,
        "source_revision_id": source["revision_id"],
        "chunk_count": len(chunks),
        "index_eligible_count": sum(bool(chunk["index_eligible"]) for chunk in chunks),
        "manual_review_count": sum(chunk["review_status"] == "manual_review_required" for chunk in chunks),
        "chunks_sha256": chunks_sha256,
    }
