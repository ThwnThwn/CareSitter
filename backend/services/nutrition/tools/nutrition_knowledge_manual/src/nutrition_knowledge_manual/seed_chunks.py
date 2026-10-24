from __future__ import annotations

from contextlib import closing
import hashlib
import json
from pathlib import Path
import sqlite3
from typing import Any

from .chunk_pdf import lexical_tokens
from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json


def _validated_chunks(
    *, source: dict[str, Any], chunks_path: Path, report_path: Path
) -> tuple[list[dict[str, Any]], str]:
    report = load_json(report_path)
    report_content = {
        key: value for key, value in report.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    if report.get("content_sha256") != content_sha256(report_content):
        raise ManualGraphError("chunk report content hash is invalid")
    for key, expected in (
        ("source_id", source["source_id"]),
        ("source_revision_id", source["revision_id"]),
        ("source_sha256", source["sha256"]),
    ):
        if report.get(key) != expected:
            raise ManualGraphError(f"chunk report {key} does not match the source")
    chunks_sha256 = file_sha256(chunks_path)
    if report.get("output_sha256") != chunks_sha256:
        raise ManualGraphError("chunk file hash does not match the report")

    chunks: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    with chunks_path.open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, start=1):
            try:
                chunk = json.loads(line)
            except json.JSONDecodeError as error:
                raise ManualGraphError(f"invalid chunk JSON at line {line_number}") from error
            if not isinstance(chunk, dict):
                raise ManualGraphError(f"invalid chunk record at line {line_number}")
            for key, expected in (
                ("source_id", source["source_id"]),
                ("source_revision_id", source["revision_id"]),
                ("source_sha256", source["sha256"]),
            ):
                if chunk.get(key) != expected:
                    raise ManualGraphError(f"chunk line {line_number} has mismatched {key}")
            chunk_id = chunk.get("chunk_id")
            if not isinstance(chunk_id, str) or not chunk_id.startswith("nutrition-chunk-"):
                raise ManualGraphError(f"chunk line {line_number} has an invalid ID")
            if chunk_id in seen_ids:
                raise ManualGraphError(f"duplicate chunk ID at line {line_number}")
            seen_ids.add(chunk_id)
            text = chunk.get("text")
            if not isinstance(text, str) or not text.strip():
                raise ManualGraphError(f"chunk line {line_number} has no text")
            if hashlib.sha256(text.encode("utf-8")).hexdigest() != chunk.get("text_sha256"):
                raise ManualGraphError(f"chunk line {line_number} has an invalid text hash")
            if not isinstance(chunk.get("pdf_page"), int) or chunk["pdf_page"] < 1:
                raise ManualGraphError(f"chunk line {line_number} has an invalid PDF page")
            if chunk["pdf_page"] > report.get("pdf_page_count", 0):
                raise ManualGraphError(f"chunk line {line_number} exceeds the PDF page count")
            ordinal = chunk.get("chunk_ordinal_on_page")
            if not isinstance(ordinal, int) or ordinal < 1 or ordinal != chunk.get("chunk_ordinal_at_locator"):
                raise ManualGraphError(f"chunk line {line_number} has an invalid page ordinal")
            identity = (
                f"{source['revision_id']}|pdf-page:{chunk['pdf_page']}|{ordinal}|{text}"
            ).encode("utf-8")
            if chunk_id != "nutrition-chunk-" + hashlib.sha256(identity).hexdigest()[:24]:
                raise ManualGraphError(f"chunk line {line_number} has a mismatched ID")
            if chunk.get("token_count") != len(lexical_tokens(text)):
                raise ManualGraphError(f"chunk line {line_number} has an invalid token count")
            if chunk["token_count"] > report.get("maximum_tokens", 0):
                raise ManualGraphError(f"chunk line {line_number} exceeds the token limit")
            if not isinstance(chunk.get("headings"), list):
                raise ManualGraphError(f"chunk line {line_number} has invalid headings")
            if chunk.get("content_type") not in {"text", "table_candidate"}:
                raise ManualGraphError(f"chunk line {line_number} has an invalid content type")
            if chunk.get("review_status") not in {"ready_for_retrieval_eval", "manual_review_required"}:
                raise ManualGraphError(f"chunk line {line_number} has an invalid review status")
            if chunk.get("index_eligible") != (chunk["review_status"] == "ready_for_retrieval_eval"):
                raise ManualGraphError(f"chunk line {line_number} has inconsistent eligibility")
            if chunk["index_eligible"] != (chunk["content_type"] == "text" and chunk["token_count"] >= 80):
                raise ManualGraphError(f"chunk line {line_number} bypasses the review gate")
            chunks.append(chunk)
    if len(chunks) != report.get("chunk_count") or not chunks:
        raise ManualGraphError("chunk count does not match the report")
    if sum(bool(chunk["index_eligible"]) for chunk in chunks) != report.get("index_eligible_count"):
        raise ManualGraphError("eligible chunk count does not match the report")
    return chunks, chunks_sha256


def seed_local_chunks(
    *, source: dict[str, Any], chunks_path: Path, report_path: Path, database_path: Path
) -> dict[str, Any]:
    """Seed a local evidence index only; never publish clinical catalog content."""
    chunks, chunks_sha256 = _validated_chunks(
        source=source, chunks_path=chunks_path, report_path=report_path
    )
    database_path.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(database_path)) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        with connection:
            connection.executescript("""
                CREATE TABLE IF NOT EXISTS source_documents (
                    source_revision_id TEXT PRIMARY KEY,
                    source_id TEXT NOT NULL,
                    source_sha256 TEXT NOT NULL,
                    chunks_sha256 TEXT NOT NULL,
                    chunk_count INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS chunks (
                    chunk_id TEXT PRIMARY KEY,
                    source_revision_id TEXT NOT NULL REFERENCES source_documents(source_revision_id),
                    pdf_page INTEGER NOT NULL,
                    printed_page TEXT,
                    ordinal_on_page INTEGER NOT NULL,
                    content_type TEXT NOT NULL,
                    review_status TEXT NOT NULL,
                    index_eligible INTEGER NOT NULL CHECK (index_eligible IN (0, 1)),
                    token_count INTEGER NOT NULL,
                    headings_json TEXT NOT NULL,
                    text TEXT NOT NULL,
                    text_sha256 TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS ix_chunks_source_page
                    ON chunks(source_revision_id, pdf_page, ordinal_on_page);
            """)
            existing = connection.execute(
                "SELECT source_sha256, chunks_sha256, chunk_count FROM source_documents "
                "WHERE source_revision_id = ?", (source["revision_id"],)
            ).fetchone()
            if existing is not None:
                if existing != (source["sha256"], chunks_sha256, len(chunks)):
                    raise ManualGraphError("source revision is already seeded with different content")
                stored = connection.execute(
                    "SELECT COUNT(*) FROM chunks WHERE source_revision_id = ?", (source["revision_id"],)
                ).fetchone()[0]
                if stored != len(chunks):
                    raise ManualGraphError("seeded chunk count does not match the source record")
                stored_rows = connection.execute(
                    "SELECT chunk_id, text_sha256 FROM chunks WHERE source_revision_id = ? ORDER BY chunk_id",
                    (source["revision_id"],),
                ).fetchall()
                expected_rows = sorted((chunk["chunk_id"], chunk["text_sha256"]) for chunk in chunks)
                if stored_rows != expected_rows:
                    raise ManualGraphError("seeded chunks differ from the verified chunk file")
                status = "already_seeded"
            else:
                connection.execute(
                    "INSERT INTO source_documents VALUES (?, ?, ?, ?, ?)",
                    (source["revision_id"], source["source_id"], source["sha256"],
                     chunks_sha256, len(chunks)),
                )
                connection.executemany(
                    "INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    [(
                        chunk["chunk_id"], source["revision_id"], chunk["pdf_page"],
                        chunk.get("printed_page"), chunk["chunk_ordinal_on_page"],
                        chunk["content_type"], chunk["review_status"],
                        int(chunk["index_eligible"]), chunk["token_count"],
                        json.dumps(chunk["headings"], ensure_ascii=False),
                        chunk["text"], chunk["text_sha256"],
                    ) for chunk in chunks],
                )
                status = "seeded"
    return {
        "status": status,
        "source_id": source["source_id"],
        "source_revision_id": source["revision_id"],
        "chunk_count": len(chunks),
        "index_eligible_count": sum(bool(chunk["index_eligible"]) for chunk in chunks),
        "manual_review_count": sum(chunk["review_status"] == "manual_review_required" for chunk in chunks),
        "chunks_sha256": chunks_sha256,
        "database_path": str(database_path.resolve()),
    }
