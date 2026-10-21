from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256


def empty_decision_ledger(graph: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "graph_content_sha256": graph["content_sha256"],
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "decisions": [],
    }


def append_decision(
    *, graph: dict[str, Any], ledger: dict[str, Any], candidate_id: str, decision: str,
    reviewer_id: str, reviewer_role: str, comment: str, policy: dict[str, Any]
) -> dict[str, Any]:
    _bind(graph, ledger)
    if decision not in {"approve", "reject"}:
        raise ManualGraphError("decision must be approve or reject")
    if not reviewer_id.strip() or not comment.strip():
        raise ManualGraphError("reviewer_id and a non-empty review comment are required")
    candidates = {item["candidate_id"]: item for item in graph["candidates"]}
    candidate = candidates.get(candidate_id)
    if candidate is None:
        raise ManualGraphError(f"candidate does not exist: {candidate_id}")
    allowed = set((policy.get("roles") or {}).get(reviewer_role) or [])
    if candidate["kind"] not in allowed:
        raise ManualGraphError(f"reviewer role {reviewer_role!r} cannot decide candidate kind {candidate['kind']!r}")
    decisions = [item for item in ledger.get("decisions", []) if item.get("candidate_id") != candidate_id]
    decisions.append({
        "candidate_id": candidate_id,
        "candidate_sha256": candidate["candidate_sha256"],
        "decision": decision,
        "reviewer_id": reviewer_id.strip(),
        "reviewer_role": reviewer_role,
        "comment": comment.strip(),
        "reviewed_at_utc": datetime.now(timezone.utc).isoformat(),
    })
    decisions.sort(key=lambda item: item["candidate_id"])
    return {**ledger, "decisions": decisions}


def materialize_reviewed_graph(graph: dict[str, Any], ledger: dict[str, Any], policy: dict[str, Any]) -> dict[str, Any]:
    _bind(graph, ledger)
    candidates = {item["candidate_id"]: item for item in graph["candidates"]}
    decisions = ledger.get("decisions") or []
    by_candidate: dict[str, dict[str, Any]] = {}
    for decision in decisions:
        candidate_id = decision.get("candidate_id")
        if candidate_id in by_candidate:
            raise ManualGraphError(f"decision ledger repeats candidate: {candidate_id}")
        candidate = candidates.get(candidate_id)
        if candidate is None or decision.get("candidate_sha256") != candidate.get("candidate_sha256"):
            raise ManualGraphError(f"review decision is stale or tampered: {candidate_id}")
        if decision.get("decision") not in {"approve", "reject"}:
            raise ManualGraphError(f"review decision is invalid: {candidate_id}")
        if not str(decision.get("reviewer_id") or "").strip() or not str(decision.get("comment") or "").strip():
            raise ManualGraphError(f"review identity or comment is missing: {candidate_id}")
        allowed = set((policy.get("roles") or {}).get(decision.get("reviewer_role")) or [])
        if candidate["kind"] not in allowed:
            raise ManualGraphError(f"review role is insufficient for candidate: {candidate_id}")
        by_candidate[candidate_id] = decision

    approved = [item for item in graph["candidates"] if by_candidate.get(item["candidate_id"], {}).get("decision") == "approve"]
    approved_nodes = {
        item["payload"]["id"] for item in approved if item["payload"].get("record_type") == "node"
    }
    records: list[dict[str, Any]] = []
    blocked_edges: list[str] = []
    for item in approved:
        payload = item["payload"]
        if payload.get("record_type") == "edge" and (
            payload.get("subject") not in approved_nodes or payload.get("object") not in approved_nodes
        ):
            blocked_edges.append(item["candidate_id"])
            continue
        records.append({
            "candidate_id": item["candidate_id"], "candidate_sha256": item["candidate_sha256"],
            "payload": payload, "review": by_candidate[item["candidate_id"]]
        })
    records.sort(key=lambda item: item["candidate_id"])
    result = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_graph_sha256": graph["content_sha256"],
        "mode": "reviewed_local_graph_not_published",
        "record_count": len(records),
        "pending_count": len(candidates) - len(by_candidate),
        "rejected_count": sum(1 for item in by_candidate.values() if item.get("decision") == "reject"),
        "blocked_edge_candidate_ids": blocked_edges,
        "records": records,
    }
    result["content_sha256"] = content_sha256({key: value for key, value in result.items() if key not in {"created_at_utc", "content_sha256"}})
    return result


def _bind(graph: dict[str, Any], ledger: dict[str, Any]) -> None:
    stable_graph = {key: value for key, value in graph.items() if key not in {"created_at_utc", "content_sha256"}}
    if graph.get("content_sha256") != content_sha256(stable_graph):
        raise ManualGraphError("candidate graph content hash is invalid")
    seen: set[str] = set()
    for candidate in graph.get("candidates") or []:
        expected = content_sha256({
            "source_revision": candidate.get("source_revision"),
            "kind": candidate.get("kind"),
            "payload": candidate.get("payload"),
        })
        candidate_id = candidate.get("candidate_id")
        if candidate_id in seen:
            raise ManualGraphError(f"candidate graph repeats id: {candidate_id}")
        seen.add(candidate_id)
        if candidate.get("candidate_sha256") != expected or candidate_id != f"cand:{expected[:24]}":
            raise ManualGraphError(f"candidate content hash is invalid: {candidate_id}")
    if ledger.get("graph_content_sha256") != graph.get("content_sha256"):
        raise ManualGraphError("decision ledger belongs to a different candidate graph")
