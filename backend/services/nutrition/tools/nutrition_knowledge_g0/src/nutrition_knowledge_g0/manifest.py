from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .errors import ContractError, GateError
from .jsonio import load_json, sha256_file


RIGHTS_STATUSES = frozenset({"synthetic", "permitted", "unverified", "denied"})
INDEXABLE_STATUSES = frozenset({"synthetic", "permitted"})
ALLOWED_USES = frozenset({"metadata", "local_index", "local_query", "internal_citation"})


@dataclass(frozen=True)
class SourceRecord:
    source_id: str
    revision_id: str
    path: str
    sha256: str
    rights_status: str
    allowed_uses: tuple[str, ...]


def validate_manifest(path: Path, workspace_root: Path) -> list[SourceRecord]:
    payload = load_json(path)
    if payload.get("schema_version") != 1 or not isinstance(payload.get("sources"), list):
        raise ContractError("Manifest must use schema_version 1 and contain sources")
    records: list[SourceRecord] = []
    source_ids: set[str] = set()
    for item in payload["sources"]:
        record = _validate_source(item, workspace_root)
        if record.source_id in source_ids:
            raise ContractError(f"Duplicate source_id: {record.source_id}")
        source_ids.add(record.source_id)
        records.append(record)
    return records


def assert_use_allowed(record: SourceRecord, requested_use: str) -> None:
    if requested_use not in ALLOWED_USES:
        raise GateError(f"Unknown requested use: {requested_use}")
    if record.rights_status not in INDEXABLE_STATUSES:
        raise GateError(f"Source {record.source_id} is {record.rights_status}, so {requested_use} is blocked")
    if requested_use not in record.allowed_uses:
        raise GateError(f"Source {record.source_id} does not permit {requested_use}")


def _validate_source(item: dict[str, Any], workspace_root: Path) -> SourceRecord:
    required = {
        "source_id", "revision_id", "title", "path", "sha256", "byte_size",
        "mime", "language", "rights_status", "allowed_uses", "rights_evidence",
        "checked_by", "checked_at_utc",
    }
    missing = sorted(required - item.keys())
    if missing:
        raise ContractError(f"Manifest source is missing fields: {', '.join(missing)}")
    status = item["rights_status"]
    if status not in RIGHTS_STATUSES:
        raise ContractError(f"Invalid rights_status for {item['source_id']}: {status}")
    uses = tuple(item["allowed_uses"])
    if not set(uses).issubset(ALLOWED_USES):
        raise ContractError(f"Invalid allowed_uses for {item['source_id']}")
    if status in {"unverified", "denied"} and set(uses) - {"metadata"}:
        raise ContractError(f"{status} source may only allow metadata: {item['source_id']}")
    if status == "permitted" and not str(item["rights_evidence"]).strip():
        raise ContractError(f"Permitted source requires rights evidence: {item['source_id']}")

    source_path = (workspace_root / item["path"]).resolve()
    if not source_path.is_relative_to(workspace_root.resolve()):
        raise ContractError(f"Source path escapes the workspace: {item['source_id']}")
    if not source_path.is_file():
        raise ContractError(f"Source path does not exist: {source_path}")
    actual_hash = sha256_file(source_path)
    if actual_hash.casefold() != str(item["sha256"]).casefold():
        raise ContractError(f"SHA-256 mismatch for {item['source_id']}")
    if source_path.stat().st_size != item["byte_size"]:
        raise ContractError(f"Byte size mismatch for {item['source_id']}")

    return SourceRecord(
        source_id=item["source_id"],
        revision_id=item["revision_id"],
        path=item["path"],
        sha256=actual_hash,
        rights_status=status,
        allowed_uses=uses,
    )
