"""Build local, review-only evidence packets for proposed catalog claims."""
from __future__ import annotations

from .errors import ManualGraphError
from .jsonio import content_sha256
from .retrieval_artifacts import sign
from .retrieval_benchmark import validate_hits


def build_catalog_evidence_packet(*, claims: dict, chunks: list[dict], retriever,
                                  bindings: dict, strategy: str) -> dict:
    if not isinstance(claims, dict) or claims.get("schema_version") != 1 or set(claims) != {"schema_version", "claims"}:
        raise ManualGraphError("catalog evidence claims must use the exact version 1 schema")
    items = claims["claims"]
    if not isinstance(items, list) or not 1 <= len(items) <= 100:
        raise ManualGraphError("catalog evidence requires 1..100 claims")
    if strategy not in {"keyword", "vector", "hybrid", "graph"}:
        raise ManualGraphError("unsupported catalog evidence strategy")
    lookup = {chunk["chunk_id"]: chunk for chunk in chunks}
    seen = set()
    rows = []
    for item in items:
        if not isinstance(item, dict) or set(item) != {"candidate_id", "claim"}:
            raise ManualGraphError("catalog evidence claim has invalid fields")
        candidate_id, claim = item["candidate_id"], item["claim"]
        if (not isinstance(candidate_id, str) or not candidate_id.strip() or len(candidate_id) > 100
                or candidate_id in seen or not isinstance(claim, str) or not claim.strip() or len(claim) > 500):
            raise ManualGraphError("catalog evidence claim is missing, duplicated or too long")
        seen.add(candidate_id)
        hits = retriever.search(claim, 5)
        validate_hits(hits, lookup)
        evidence = [{**hit, "excerpt": lookup[hit["chunk_id"]]["text"][:400]}
                    for hit in hits]
        rows.append({"candidate_id": candidate_id, "proposed_claim": claim,
                     "evidence_status": "candidate_hits_unverified" if evidence else "no_evidence_found",
                     "clinical_review": "pending", "evidence": evidence})
    return sign({"schema_version": 1, "mode": "catalog_evidence_review_packet",
                 "status": "candidate_review_required", "release_ready": False,
                 "gate_failures": ["catalog_evidence.requires_independent_review"],
                 "source_claims_sha256": content_sha256(claims), "bindings": bindings,
                 "strategy": strategy, "claims": rows})
