"""Deterministic review exports and fail-closed batch imports for M4 T1."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256
from .retrieval_artifacts import sign, verify
from .retrieval_eval import load_retrieval_chunks
from .retrieval_graph import validate_candidate, validate_graph_review
from .retrieval_review import (
    CLINICAL_REVIEW_ROLES,
    DATA_REVIEW_ROLES,
    validate_retrieval_review_ledger,
)

EXPORT_MODE = "retrieval_review_export"
BATCH_MODE = "retrieval_review_decision_batch"
PLAN_MODE = "retrieval_review_import_plan"


def build_case_review_export(*, cases: dict[str, Any], corpus_freeze: dict[str, Any],
                             ledger: dict[str, Any], chunks_path: Path,
                             owner_approval: dict[str, Any] | None = None) -> dict[str, Any]:
    hashes = validate_retrieval_review_ledger(cases=cases, corpus_freeze=corpus_freeze, ledger=ledger)
    chunks = _chunks(chunks_path)
    owner = _owner_decisions(owner_approval, cases, ledger)
    records = []
    for case in sorted(cases["cases"], key=lambda row: row["case_id"]):
        citations = [_chunk_reference(chunks[cid]) for cid in case["relevant_chunk_ids"]]
        records.append({
            "case_id": case["case_id"], "record_sha256": hashes[case["case_id"]],
            "question": case["question"], "answerability": case["answerability"],
            "split": case["split"], "candidate_citations": citations,
            "owner_approval": owner.get(case["case_id"]),
            "source_locator_review": _ledger_case(ledger, case["case_id"])["source_locator_review"],
            "clinical_relevance_review": _ledger_case(ledger, case["case_id"])["clinical_relevance_review"],
            "decision_template": {"decision": None, "comment": None},
        })
    target_hash = ledger["evaluation_content_sha256"]
    return sign({
        "schema_version": 1, "mode": EXPORT_MODE, "target_kind": "case",
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "target_content_sha256": target_hash,
        "ledger_content_sha256": ledger["content_sha256"], "records": records,
        "decision_batch_template": _batch_template("case", corpus_freeze["content_sha256"],
            target_hash, ledger["content_sha256"], records),
    })


def build_graph_review_export(*, candidate: dict[str, Any], corpus_freeze: dict[str, Any],
                              ledger: dict[str, Any], chunks_path: Path) -> dict[str, Any]:
    records_by_id = validate_graph_review(candidate, corpus_freeze, ledger)
    chunks = _chunks(chunks_path)
    records = []
    for record_id in sorted(records_by_id):
        row = records_by_id[record_id]
        evidence = [_chunk_reference(chunks[cid]) for cid in row["evidence_chunk_ids"]]
        scope_ids = row.get("scope_evidence_chunk_ids") or []
        scope = [_chunk_reference(chunks[cid]) for cid in scope_ids]
        entry = ledger["records"][record_id]
        records.append({
            "record_id": record_id, "record_sha256": entry["record_sha256"],
            "record_type": row["type"], "label": row.get("label"), "heading": row.get("heading"),
            "scope_basis": row.get("scope_basis"), "scope_evidence_chunk_ids": scope_ids,
            "evidence": evidence, "scope_evidence": scope,
            "source_review": entry["source_review"], "clinical_review": entry["clinical_review"],
            "decision_template": {"decision": None, "comment": None},
        })
    target_hash = candidate["content_sha256"]
    return sign({
        "schema_version": 1, "mode": EXPORT_MODE, "target_kind": "graph",
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "target_content_sha256": target_hash,
        "ledger_content_sha256": ledger["content_sha256"], "records": records,
        "decision_batch_template": _batch_template("graph", corpus_freeze["content_sha256"],
            target_hash, ledger["content_sha256"], records),
    })


def plan_review_import(*, target: dict[str, Any], corpus_freeze: dict[str, Any],
                       ledger: dict[str, Any], batch: dict[str, Any], batch_path: Path) -> dict[str, Any]:
    if not isinstance(batch, dict) or batch.get("schema_version") != 1 or batch.get("mode") != BATCH_MODE:
        raise ManualGraphError("invalid review decision batch")
    unsigned_batch_hash = content_sha256({key: value for key, value in batch.items()
                                          if key != "content_sha256"})
    if batch.get("content_sha256") not in {None, unsigned_batch_hash}:
        raise ManualGraphError("tampered review decision batch")
    kind = batch.get("target_kind")
    records, expected_target, ledger_entries = _target_records(kind, target, corpus_freeze, ledger)
    problems = {name: [] for name in ("accepted", "missing", "duplicate", "stale_hash",
                                      "conflict", "wrong_role", "unchanged")}
    if batch.get("corpus_freeze_sha256") != corpus_freeze.get("content_sha256") \
            or batch.get("target_content_sha256") != expected_target:
        raise ManualGraphError("review batch is stale or belongs to another target")
    source = batch.get("decision_source")
    if not isinstance(source, dict) or source.get("attested") is not True \
            or source.get("type") != "completed_review_file" or not _text(source.get("reference")):
        raise ManualGraphError("review batch lacks an attested decision source")
    reviewer_id, role = _text(batch.get("reviewer_id")), batch.get("reviewer_role")
    decisions = batch.get("decisions")
    if not reviewer_id or not isinstance(decisions, list) or not decisions:
        raise ManualGraphError("review batch reviewer and decisions are required")
    valid_roles = DATA_REVIEW_ROLES | CLINICAL_REVIEW_ROLES
    seen: dict[str, dict[str, Any]] = {}
    id_key = "case_id" if kind == "case" else "record_id"
    for row in decisions:
        record_id = row.get(id_key) if isinstance(row, dict) else None
        if not _text(record_id) or record_id not in records:
            problems["missing"].append(str(record_id))
            continue
        if record_id in seen:
            category = "duplicate" if row == seen[record_id] else "conflict"
            problems[category].append(record_id)
            continue
        seen[record_id] = row
        if role not in valid_roles:
            problems["wrong_role"].append(record_id)
            continue
        if row.get("record_sha256") != records[record_id]:
            problems["stale_hash"].append(record_id)
            continue
        if row.get("decision") not in {"approved", "rejected"} or not _text(row.get("comment")):
            problems["conflict"].append(record_id)
            continue
        slot, other_slot = _slots(kind, role)
        entry = ledger_entries[record_id]
        other = entry.get(other_slot)
        if other is not None and other.get("reviewer_id") == reviewer_id:
            problems["wrong_role"].append(record_id)
            continue
        existing = entry.get(slot)
        intended = {"reviewer_id": reviewer_id, "reviewer_role": role,
                    "decision": row["decision"], "comment": row["comment"]}
        if existing is None:
            problems["accepted"].append(record_id)
        elif all(existing.get(key) == value for key, value in intended.items()):
            problems["unchanged"].append(record_id)
        else:
            problems["conflict"].append(record_id)
    batch_file = batch_path.resolve()
    batch_file_hash = file_sha256(batch_file)
    prior_receipt = next((item for item in ledger.get("import_receipts", [])
                          if item.get("batch_content_sha256") == unsigned_batch_hash
                          and item.get("batch_file_sha256") == batch_file_hash
                          and item.get("reviewer_id") == reviewer_id
                          and item.get("reviewer_role") == role), None)
    if batch.get("ledger_content_sha256") != ledger.get("content_sha256"):
        if prior_receipt is None:
            raise ManualGraphError("review batch is stale or belongs to another ledger")
        problems["accepted"] = []
        problems["unchanged"] = [row.get(id_key) for row in decisions if isinstance(row, dict)]
    normalized = {key: sorted(set(value)) for key, value in problems.items()}
    return sign({
        "schema_version": 1, "mode": PLAN_MODE, "target_kind": kind,
        "batch_content_sha256": unsigned_batch_hash, "batch_file_sha256": batch_file_hash,
        "batch_path": batch_file.as_posix(), "ledger_content_sha256": ledger["content_sha256"],
        "reviewer_id": reviewer_id, "reviewer_role": role, "outcomes": normalized,
        "can_apply": not any(normalized[name] for name in
                             ("missing", "duplicate", "stale_hash", "conflict", "wrong_role")),
    })


def apply_review_import(*, target: dict[str, Any], corpus_freeze: dict[str, Any],
                        ledger: dict[str, Any], batch: dict[str, Any], batch_path: Path,
                        plan: dict[str, Any], imported_at_utc: str | None = None) -> dict[str, Any]:
    verify(plan, PLAN_MODE)
    current = plan_review_import(target=target, corpus_freeze=corpus_freeze, ledger=ledger,
                                 batch=batch, batch_path=batch_path)
    if current != plan:
        raise ManualGraphError("review import changed after dry-run")
    if not plan["can_apply"]:
        raise ManualGraphError("review import plan contains blocking outcomes")
    timestamp = imported_at_utc or datetime.now(timezone.utc).isoformat()
    try:
        parsed_timestamp = datetime.fromisoformat(timestamp)
    except (TypeError, ValueError):
        raise ManualGraphError("review import timestamp must be ISO-8601") from None
    if parsed_timestamp.tzinfo is None:
        raise ManualGraphError("review import timestamp must include a timezone")
    result = deepcopy(ledger)
    kind, role = batch["target_kind"], batch["reviewer_role"]
    slot, _ = _slots(kind, role)
    id_key = "case_id" if kind == "case" else "record_id"
    accepted = set(plan["outcomes"]["accepted"])
    for row in batch["decisions"]:
        record_id = row[id_key]
        if record_id not in accepted:
            continue
        entry = (_case_entries(result) if kind == "case" else result["records"])[record_id]
        entry[slot] = {"reviewer_id": batch["reviewer_id"], "reviewer_role": role,
                       "decision": row["decision"], "comment": row["comment"],
                       "reviewed_at_utc": timestamp}
    receipt = {"batch_content_sha256": plan["batch_content_sha256"],
               "batch_file_sha256": plan["batch_file_sha256"], "batch_path": plan["batch_path"],
               "reviewer_id": batch["reviewer_id"], "reviewer_role": role,
               "imported_at_utc": timestamp, "outcomes": plan["outcomes"]}
    receipts = list(result.get("import_receipts") or [])
    if not any(item.get("batch_content_sha256") == plan["batch_content_sha256"]
               and item.get("batch_file_sha256") == plan["batch_file_sha256"] for item in receipts):
        receipts.append(receipt)
    result["import_receipts"] = receipts
    result = sign(result)
    _target_records(kind, target, corpus_freeze, result)
    return result


def _target_records(kind: Any, target: dict[str, Any], corpus_freeze: dict[str, Any],
                    ledger: dict[str, Any]) -> tuple[dict[str, str], str, dict[str, dict[str, Any]]]:
    if kind == "case":
        records = validate_retrieval_review_ledger(cases=target, corpus_freeze=corpus_freeze, ledger=ledger)
        return records, ledger["evaluation_content_sha256"], _case_entries(ledger)
    if kind == "graph":
        rows = validate_graph_review(target, corpus_freeze, ledger)
        return ({rid: content_sha256(row) for rid, row in rows.items()}, target["content_sha256"],
                ledger["records"])
    raise ManualGraphError("review batch target_kind must be case or graph")


def _slots(kind: str, role: str) -> tuple[str, str]:
    if role in DATA_REVIEW_ROLES:
        return (("source_locator_review", "clinical_relevance_review") if kind == "case"
                else ("source_review", "clinical_review"))
    if role in CLINICAL_REVIEW_ROLES:
        return (("clinical_relevance_review", "source_locator_review") if kind == "case"
                else ("clinical_review", "source_review"))
    return "", ""


def _case_entries(ledger: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {row["case_id"]: row for row in ledger["decisions"]}


def _ledger_case(ledger: dict[str, Any], case_id: str) -> dict[str, Any]:
    return _case_entries(ledger)[case_id]


def _chunks(path: Path) -> dict[str, dict[str, Any]]:
    return {row["chunk_id"]: row for row in load_retrieval_chunks(path)}


def _chunk_reference(chunk: dict[str, Any]) -> dict[str, Any]:
    return {key: chunk.get(key) for key in
            ("chunk_id", "source_revision_id", "source_locator", "pdf_page", "printed_page", "headings")}


def _owner_decisions(approval: dict[str, Any] | None, cases: dict[str, Any],
                     ledger: dict[str, Any]) -> dict[str, str]:
    if approval is None:
        return {}
    if approval.get("mode") != "product_owner_visible_case_approval" \
            or approval.get("content_sha256") != sign(approval)["content_sha256"] \
            or approval.get("case_set_sha256") != ledger["evaluation_content_sha256"]:
        raise ManualGraphError("owner approval does not match the case export")
    expected = {row["case_id"]: content_sha256(row) for row in cases["cases"]}
    result = {}
    for row in approval.get("decisions") or []:
        if expected.get(row.get("case_id")) != row.get("case_content_sha256"):
            raise ManualGraphError("owner approval contains a stale case")
        result[row["case_id"]] = row.get("owner_decision")
    return result


def _batch_template(kind: str, freeze_hash: str, target_hash: str, ledger_hash: str,
                    records: list[dict[str, Any]]) -> dict[str, Any]:
    id_key = "case_id" if kind == "case" else "record_id"
    return {
        "schema_version": 1, "mode": BATCH_MODE, "target_kind": kind,
        "corpus_freeze_sha256": freeze_hash, "target_content_sha256": target_hash,
        "ledger_content_sha256": ledger_hash, "reviewer_id": None, "reviewer_role": None,
        "decision_source": {"type": "completed_review_file", "reference": None, "attested": False},
        "decisions": [{id_key: row[id_key], "record_sha256": row["record_sha256"],
                       "decision": None, "comment": None} for row in records],
    }


def _text(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""
