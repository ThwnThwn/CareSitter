from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json
from .review import materialize_reviewed_graph
from .rights import resolve_citation_sources, resolve_source

CLINICAL_ROLES = {"dietitian", "physician"}
CLINICAL_KINDS = {"recipe", "rule", "clinical_edge"}


def prepare_release(
    *, workspace: Path, manifest_path: Path, bundle_source_id: str, evidence_path: Path,
    graph: dict[str, Any], ledger: dict[str, Any], policy: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, Any]]:
    source, bundle_path = resolve_source(
        workspace=workspace, manifest_path=manifest_path, source_id=bundle_source_id
    )
    if source["rights_status"] != "permitted":
        raise ManualGraphError("release preparation requires a permitted bundle source")
    if graph.get("source", {}).get("source_id") != source["source_id"] or \
            graph.get("source", {}).get("revision_id") != source["revision_id"]:
        raise ManualGraphError("candidate graph is not bound to the selected bundle source revision")
    if graph.get("source", {}).get("sha256") != source["sha256"]:
        raise ManualGraphError("candidate graph source hash does not match the rights manifest")

    bundle = load_json(bundle_path)
    evidence = load_json(evidence_path)
    bundle_hash = file_sha256(bundle_path)
    if evidence.get("packageKey") != bundle.get("packageKey"):
        raise ManualGraphError("release evidence packageKey does not match the bundle")
    if str(evidence.get("bundleFileSha256") or "").lower() != bundle_hash:
        raise ManualGraphError("release evidence is not bound to the exact bundle file")

    citation_ids = {item.get("id") for item in bundle.get("citations") or []}
    if None in citation_ids or "" in citation_ids:
        raise ManualGraphError("every bundle citation requires an id")
    citation_sources = resolve_citation_sources(
        workspace=workspace, manifest_path=manifest_path, citation_ids=citation_ids
    )
    if any(item["rights_status"] != "permitted" for item in citation_sources):
        raise ManualGraphError("release preparation requires every cited source to be permitted")

    reviewed = materialize_reviewed_graph(graph, ledger, policy)
    if reviewed["pending_count"] != 0 or reviewed["rejected_count"] != 0 or reviewed["blocked_edge_candidate_ids"]:
        raise ManualGraphError("every candidate must be approved before release preparation")
    if reviewed["record_count"] != graph["candidate_count"]:
        raise ManualGraphError("reviewed graph does not contain every candidate")

    candidates = {item["candidate_id"]: item for item in graph["candidates"]}
    clinical_reviewers: set[str] = set()
    reviewer_roles: dict[str, set[str]] = {}
    for decision in ledger.get("decisions") or []:
        candidate = candidates[decision["candidate_id"]]
        reviewer_id = decision["reviewer_id"]
        role = decision["reviewer_role"]
        reviewer_roles.setdefault(reviewer_id, set()).add(role)
        if candidate["kind"] in CLINICAL_KINDS:
            if role not in CLINICAL_ROLES:
                raise ManualGraphError("clinical candidates require a dietitian or physician")
            clinical_reviewers.add(reviewer_id)
    if not clinical_reviewers:
        raise ManualGraphError("at least one clinical reviewer is required")
    clinical_review = evidence.get("clinicalReview") or {}
    clinical_reviewer_id = str(clinical_review.get("reviewerId") or "").strip()
    if not clinical_reviewer_id or clinical_reviewer_id not in clinical_reviewers:
        raise ManualGraphError("clinicalReview.reviewerId must identify a clinical candidate reviewer")

    source_reviews = [{
        "sourceRevisionId": source["revision_id"], "rightsStatus": source["rights_status"]
    }]
    source_reviews.extend({
        "sourceRevisionId": item["revision_id"], "rightsStatus": item["rights_status"]
    } for item in citation_sources if item["revision_id"] != source["revision_id"])
    if len({item["sourceRevisionId"] for item in source_reviews}) != len(source_reviews):
        raise ManualGraphError("release sources must have unique revision ids")
    source_reviews.sort(key=lambda item: item["sourceRevisionId"])
    knowledge_review = {
        "schemaVersion": 1,
        "candidateGraphSha256": graph["content_sha256"],
        "decisionLedgerSha256": content_sha256(ledger),
        "reviewedGraphSha256": reviewed["content_sha256"],
        "candidateCount": graph["candidate_count"],
        "approvedCount": reviewed["record_count"],
        "pendingCount": 0,
        "rejectedCount": 0,
        "sources": source_reviews,
        "clinicalReviewerIds": sorted(clinical_reviewers),
        "decision": "approved",
    }
    output_evidence = {**evidence, "knowledgeReview": knowledge_review}
    authorization = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "package_key": bundle["packageKey"],
        "bundle_file_sha256": bundle_hash,
        "knowledge_review": knowledge_review,
        "evidence_content_sha256": content_sha256(output_evidence),
        "reviewers": [
            {"reviewer_id": reviewer_id, "roles": sorted(roles)}
            for reviewer_id, roles in sorted(reviewer_roles.items())
        ],
        "status": "release_check_required",
    }
    authorization["content_sha256"] = content_sha256({
        key: value for key, value in authorization.items() if key not in {"created_at_utc", "content_sha256"}
    })
    return output_evidence, authorization
