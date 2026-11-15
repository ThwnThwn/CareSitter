from __future__ import annotations

from pathlib import Path
from typing import Any

from .errors import ManualGraphError
from .jsonio import file_sha256, load_json

ALLOWED_RIGHTS = {"synthetic", "permitted"}
REQUIRED_USES = {"local_index", "local_query", "internal_citation"}


def resolve_source(*, workspace: Path, manifest_path: Path, source_id: str) -> tuple[dict[str, Any], Path]:
    manifest = load_json(manifest_path)
    matches = [item for item in manifest.get("sources", []) if item.get("source_id") == source_id]
    if len(matches) != 1:
        raise ManualGraphError(f"source_id must identify exactly one manifest revision: {source_id}")
    return _validate_source(workspace, matches[0])


def resolve_citation_sources(
    *, workspace: Path, manifest_path: Path, citation_ids: set[str]
) -> list[dict[str, Any]]:
    manifest = load_json(manifest_path)
    sources = manifest.get("sources", [])
    resolved: list[dict[str, Any]] = []
    for citation_id in sorted(citation_ids):
        matches = [item for item in sources if citation_id in (item.get("citation_ids") or [])]
        if len(matches) != 1:
            raise ManualGraphError(f"citation must map to exactly one rights source: {citation_id}")
        source, _ = _validate_source(workspace, matches[0])
        resolved.append(source)
    return resolved


def _validate_source(workspace: Path, source: dict[str, Any]) -> tuple[dict[str, Any], Path]:
    rights = source.get("rights_status")
    if rights not in ALLOWED_RIGHTS:
        raise ManualGraphError(f"source is metadata-only; rights_status={rights!r}")
    uses = set(source.get("allowed_uses") or [])
    missing = REQUIRED_USES - uses
    if missing:
        raise ManualGraphError(f"source is not permitted for graph use: missing {sorted(missing)}")
    raw_path = source.get("path")
    if not isinstance(raw_path, str) or not raw_path:
        raise ManualGraphError("permitted source must have a local path")
    source_path = (workspace / raw_path).resolve()
    try:
        source_path.relative_to(workspace.resolve())
    except ValueError as error:
        raise ManualGraphError("source path escapes the workspace") from error
    if not source_path.is_file():
        raise ManualGraphError(f"source file does not exist: {source_path}")
    expected_hash = source.get("sha256")
    actual_hash = file_sha256(source_path)
    if expected_hash != actual_hash:
        raise ManualGraphError(f"source hash mismatch: expected {expected_hash}, actual {actual_hash}")
    if source.get("byte_size") != source_path.stat().st_size:
        raise ManualGraphError("source byte_size does not match the manifest")
    return source, source_path
