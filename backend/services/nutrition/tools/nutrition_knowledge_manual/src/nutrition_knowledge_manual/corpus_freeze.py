from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json
from .rights import resolve_source


_ELIGIBLE_STATUS = "ready_for_retrieval_eval"
_MANUAL_STATUS = "manual_review_required"
_VALIDATION_CONTRACT_FILES = ("corpus_freeze.py", "jsonio.py", "rights.py")


def freeze_retrieval_corpus(
    *, workspace: Path, manifest_path: Path, source_id: str, chunks_path: Path, report_path: Path
) -> dict[str, Any]:
    """Create a source- and artifact-bound manifest for retrieval evaluation only."""
    source, _ = resolve_source(
        workspace=workspace, manifest_path=manifest_path, source_id=source_id
    )
    return _build_freeze(
        workspace=workspace,
        manifest_path=manifest_path,
        source=source,
        chunks_path=chunks_path,
        report_path=report_path,
    )


def validate_retrieval_corpus_freeze(
    *,
    corpus_freeze: dict[str, Any],
    workspace: Path,
    manifest_path: Path,
    source_id: str,
    chunks_path: Path,
    report_path: Path,
) -> dict[str, Any]:
    """Reject a freeze when its source, report, or corpus no longer matches disk."""
    _validate_freeze_document(corpus_freeze)
    source, _ = resolve_source(
        workspace=workspace, manifest_path=manifest_path, source_id=source_id
    )
    expected = _build_freeze(
        workspace=workspace,
        manifest_path=manifest_path,
        source=source,
        chunks_path=chunks_path,
        report_path=report_path,
    )
    if corpus_freeze["content_sha256"] != expected["content_sha256"]:
        raise ManualGraphError("corpus freeze no longer matches the verified source or chunk artifacts")
    return expected


def validate_retrieval_corpus_binding(
    *, corpus_freeze: dict[str, Any], chunks_path: Path
) -> dict[str, Any]:
    """Validate a freeze document against a chunk artifact without resolving source paths."""
    _validate_freeze_document(corpus_freeze)
    if file_sha256(chunks_path) != corpus_freeze["chunks_sha256"]:
        raise ManualGraphError("chunk artifact does not match the corpus freeze")
    eligible = _read_chunks(chunks_path, maximum_tokens=corpus_freeze["chunker"]["maximum_tokens"])[0]
    identities = _eligible_identities(eligible)
    if identities != corpus_freeze["eligible_chunk_identities"]:
        raise ManualGraphError("eligible chunks do not match the corpus freeze")
    return corpus_freeze


def validate_retrieval_corpus_freeze_document(corpus_freeze: dict[str, Any]) -> None:
    """Validate a portable freeze manifest before it is bound to another artifact."""
    _validate_freeze_document(corpus_freeze)


def _build_freeze(
    *,
    workspace: Path,
    manifest_path: Path,
    source: dict[str, Any],
    chunks_path: Path,
    report_path: Path,
) -> dict[str, Any]:
    report = load_json(report_path)
    _validate_report(report=report, source=source, chunks_path=chunks_path)
    maximum_tokens = report["maximum_tokens"]
    chunks, status_counts = _read_chunks(chunks_path, maximum_tokens=maximum_tokens)
    _validate_chunk_counts(report=report, chunks=chunks, status_counts=status_counts)

    eligible = [chunk for chunk in chunks if chunk["index_eligible"]]
    excluded = [chunk for chunk in chunks if not chunk["index_eligible"]]
    source_fields = ("source_id", "source_revision_id", "source_sha256")
    expected = {
        "source_id": source["source_id"],
        "source_revision_id": source["revision_id"],
        "source_sha256": source["sha256"],
    }
    for line_number, chunk in enumerate(chunks, start=1):
        for field in source_fields:
            if chunk.get(field) != expected[field]:
                raise ManualGraphError(f"chunk line {line_number} has mismatched {field}")

    validation_contract_files = _validation_contract_hashes()
    freeze = {
        "schema_version": 1,
        "mode": "local_retrieval_corpus_freeze",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_id": source["source_id"],
        "source_revision_id": source["revision_id"],
        "source_sha256": source["sha256"],
        "validator_code_sha256": file_sha256(Path(__file__)),
        "validation_contract_files_sha256": validation_contract_files,
        "validation_contract_sha256": content_sha256(validation_contract_files),
        "source_manifest_artifact": _relative_artifact_path(workspace, manifest_path),
        "source_manifest_sha256": file_sha256(manifest_path),
        "source_artifact": _relative_artifact_path(workspace, source["path"]),
        "chunks_artifact": _relative_artifact_path(workspace, chunks_path),
        "chunk_report_artifact": _relative_artifact_path(workspace, report_path),
        "chunks_sha256": file_sha256(chunks_path),
        "chunk_report_sha256": file_sha256(report_path),
        "chunk_report_content_sha256": report["content_sha256"],
        "chunk_count": len(chunks),
        "eligible_chunk_count": len(eligible),
        "excluded_chunk_count": len(excluded),
        "excluded_by_review_status": dict(
            sorted(Counter(chunk["review_status"] for chunk in excluded).items())
        ),
        "chunker": {
            "tokenizer": report["tokenizer"],
            "target_tokens": report["target_tokens"],
            "maximum_tokens": maximum_tokens,
            "overlap_tokens": report["overlap_tokens"],
        },
        "eligible_chunk_identities": _eligible_identities(eligible),
    }
    return _sign_freeze(freeze)


def _validate_report(*, report: Any, source: dict[str, Any], chunks_path: Path) -> None:
    if not isinstance(report, dict) or report.get("schema_version") != 1:
        raise ManualGraphError("chunk report schema_version must be 1")
    supplied_hash = report.get("content_sha256")
    unsigned = {
        key: value for key, value in report.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    if supplied_hash != content_sha256(unsigned):
        raise ManualGraphError("chunk report content hash is invalid")
    for field, expected in (
        ("source_id", source["source_id"]),
        ("source_revision_id", source["revision_id"]),
        ("source_sha256", source["sha256"]),
        ("rights_status", source["rights_status"]),
    ):
        if report.get(field) != expected:
            raise ManualGraphError(f"chunk report {field} does not match the verified source")
    if report.get("output_sha256") != file_sha256(chunks_path):
        raise ManualGraphError("chunk file hash does not match the report")
    for field in ("chunk_count", "index_eligible_count", "target_tokens", "maximum_tokens", "overlap_tokens"):
        if not isinstance(report.get(field), int):
            raise ManualGraphError(f"chunk report {field} must be an integer")
    if not 100 <= report["target_tokens"] <= report["maximum_tokens"] <= 1200:
        raise ManualGraphError("chunk report token limits are invalid")
    if not 0 <= report["overlap_tokens"] < report["target_tokens"]:
        raise ManualGraphError("chunk report overlap is invalid")
    if not isinstance(report.get("tokenizer"), str) or not report["tokenizer"].strip():
        raise ManualGraphError("chunk report tokenizer is required")


def _read_chunks(chunks_path: Path, *, maximum_tokens: int) -> tuple[list[dict[str, Any]], Counter[str]]:
    chunks: list[dict[str, Any]] = []
    status_counts: Counter[str] = Counter()
    seen_ids: set[str] = set()
    with chunks_path.open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, start=1):
            try:
                chunk = json.loads(line)
            except json.JSONDecodeError as error:
                raise ManualGraphError(f"invalid chunk JSON at line {line_number}") from error
            if not isinstance(chunk, dict):
                raise ManualGraphError(f"invalid chunk record at line {line_number}")
            chunk_id = chunk.get("chunk_id")
            if not isinstance(chunk_id, str) or not chunk_id.strip() or chunk_id in seen_ids:
                raise ManualGraphError(f"duplicate or invalid chunk ID at line {line_number}")
            seen_ids.add(chunk_id)
            locator = chunk.get("source_locator")
            if not isinstance(locator, str) or not locator.strip():
                raise ManualGraphError(f"chunk line {line_number} has no source locator")
            text = chunk.get("text")
            if not isinstance(text, str) or not text.strip():
                raise ManualGraphError(f"chunk line {line_number} has no text")
            if hashlib.sha256(text.encode("utf-8")).hexdigest() != chunk.get("text_sha256"):
                raise ManualGraphError(f"chunk line {line_number} has an invalid text hash")
            token_count = chunk.get("token_count")
            if not isinstance(token_count, int) or token_count < 1 or token_count > maximum_tokens:
                raise ManualGraphError(f"chunk line {line_number} has an invalid token count")
            review_status = chunk.get("review_status")
            index_eligible = chunk.get("index_eligible")
            if review_status not in {_ELIGIBLE_STATUS, _MANUAL_STATUS}:
                raise ManualGraphError(f"chunk line {line_number} has an invalid review status")
            if index_eligible is not (review_status == _ELIGIBLE_STATUS):
                raise ManualGraphError(f"chunk line {line_number} bypasses the review gate")
            if not isinstance(chunk.get("headings"), list):
                raise ManualGraphError(f"chunk line {line_number} has invalid headings")
            status_counts[review_status] += 1
            chunks.append(chunk)
    if not chunks:
        raise ManualGraphError("chunk file has no records")
    return chunks, status_counts


def _validate_chunk_counts(*, report: dict[str, Any], chunks: list[dict[str, Any]], status_counts: Counter[str]) -> None:
    if report["chunk_count"] != len(chunks):
        raise ManualGraphError("chunk count does not match the report")
    if report["index_eligible_count"] != sum(chunk["index_eligible"] for chunk in chunks):
        raise ManualGraphError("eligible chunk count does not match the report")
    if report.get("review_status_counts") != dict(sorted(status_counts.items())):
        raise ManualGraphError("review status counts do not match the report")


def _eligible_identities(chunks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result = []
    for chunk in chunks:
        if not chunk.get("index_eligible"):
            continue
        result.append({
            "chunk_id": chunk["chunk_id"],
            "text_sha256": chunk["text_sha256"],
            "source_locator": chunk["source_locator"],
            "pdf_page": chunk.get("pdf_page"),
            "printed_page": chunk.get("printed_page"),
        })
    return sorted(result, key=lambda item: item["chunk_id"])


def _relative_artifact_path(workspace: Path, path: str | Path) -> str:
    candidate = (workspace / path).resolve() if not Path(path).is_absolute() else Path(path).resolve()
    try:
        return candidate.relative_to(workspace.resolve()).as_posix()
    except ValueError as error:
        raise ManualGraphError("freeze artifacts must remain inside the workspace") from error


def _sign_freeze(freeze: dict[str, Any]) -> dict[str, Any]:
    unsigned = {
        key: value for key, value in freeze.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    return {**freeze, "content_sha256": content_sha256(unsigned)}


def _validation_contract_hashes() -> dict[str, str]:
    module_directory = Path(__file__).resolve().parent
    return {
        name: file_sha256(module_directory / name)
        for name in _VALIDATION_CONTRACT_FILES
    }


def _validate_freeze_document(corpus_freeze: dict[str, Any]) -> None:
    if not isinstance(corpus_freeze, dict):
        raise ManualGraphError("corpus freeze must be an object")
    if corpus_freeze.get("schema_version") != 1:
        raise ManualGraphError("corpus freeze schema_version must be 1")
    if corpus_freeze.get("mode") != "local_retrieval_corpus_freeze":
        raise ManualGraphError("corpus freeze mode is invalid")
    unsigned = {
        key: value for key, value in corpus_freeze.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    if corpus_freeze.get("content_sha256") != content_sha256(unsigned):
        raise ManualGraphError("corpus freeze content hash is invalid")
    required_hashes = (
        "source_sha256",
        "source_manifest_sha256",
        "chunks_sha256",
        "chunk_report_sha256",
        "chunk_report_content_sha256",
        "validator_code_sha256",
        "validation_contract_sha256",
    )
    if any(not isinstance(corpus_freeze.get(field), str) or len(corpus_freeze[field]) != 64 for field in required_hashes):
        raise ManualGraphError("corpus freeze is missing a valid artifact hash")
    if corpus_freeze["validator_code_sha256"] != file_sha256(Path(__file__)):
        raise ManualGraphError("corpus freeze was created by a different validator code revision")
    expected_contract_files = _validation_contract_hashes()
    if corpus_freeze.get("validation_contract_files_sha256") != expected_contract_files:
        raise ManualGraphError("corpus freeze was created by a different validation contract revision")
    if corpus_freeze["validation_contract_sha256"] != content_sha256(expected_contract_files):
        raise ManualGraphError("corpus freeze validation contract hash is invalid")
    identities = corpus_freeze.get("eligible_chunk_identities")
    if not isinstance(identities, list) or not identities:
        raise ManualGraphError("corpus freeze has no eligible chunk identities")
    identity_ids: set[str] = set()
    for identity in identities:
        if not isinstance(identity, dict):
            raise ManualGraphError("corpus freeze chunk identity is invalid")
        chunk_id = identity.get("chunk_id")
        if not isinstance(chunk_id, str) or not chunk_id or chunk_id in identity_ids:
            raise ManualGraphError("corpus freeze repeats an eligible chunk ID")
        identity_ids.add(chunk_id)
        if not isinstance(identity.get("source_locator"), str) or not identity["source_locator"].strip():
            raise ManualGraphError("corpus freeze eligible chunk has no locator")
        if not isinstance(identity.get("text_sha256"), str) or len(identity["text_sha256"]) != 64:
            raise ManualGraphError("corpus freeze eligible chunk has no valid text hash")
    if corpus_freeze.get("eligible_chunk_count") != len(identities):
        raise ManualGraphError("corpus freeze eligible chunk count is invalid")
    chunker = corpus_freeze.get("chunker")
    if not isinstance(chunker, dict) or not isinstance(chunker.get("maximum_tokens"), int):
        raise ManualGraphError("corpus freeze chunker metadata is invalid")
