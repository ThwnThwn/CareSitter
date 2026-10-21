from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256


DATA_REVIEW_ROLES = {"data_steward"}
CLINICAL_REVIEW_ROLES = {"dietitian", "physician"}


def empty_catalog_review(candidate_manifest: dict[str, Any]) -> dict[str, Any]:
    """Create a hash-bound empty review ledger for one catalog candidate manifest."""
    candidates = validate_candidate_manifest(candidate_manifest)
    ledger = {
        "schema_version": 1,
        "candidate_manifest_sha256": candidate_manifest["content_sha256"],
        "decisions": [
            {
                "recipe_version_id": recipe_version_id,
                "candidate_sha256": candidates[recipe_version_id],
                "data_review": None,
                "clinical_review": None,
                "resolutions": [],
            }
            for recipe_version_id in sorted(candidates)
        ],
        "clinical_review": None,
    }
    return _sign_ledger(ledger)


def record_recipe_review(
    *,
    candidate_manifest: dict[str, Any],
    ledger: dict[str, Any],
    recipe_version_id: str,
    decision: str,
    reviewer_id: str,
    reviewer_role: str,
    comment: str,
    resolutions: list[dict[str, str]] | None = None,
    reviewed_at_utc: str | None = None,
) -> dict[str, Any]:
    """Record one role's recipe review while preserving all other decisions."""
    candidates = validate_catalog_review_ledger(candidate_manifest, ledger)
    if recipe_version_id not in candidates:
        raise ManualGraphError(f"recipe candidate does not exist: {recipe_version_id}")
    if decision not in {"approved", "rejected"}:
        raise ManualGraphError("recipe review decision must be approved or rejected")
    reviewer_id = _required_text(reviewer_id, "reviewer_id")
    comment = _required_text(comment, "comment")
    if reviewer_role in DATA_REVIEW_ROLES:
        slot = "data_review"
    elif reviewer_role in CLINICAL_REVIEW_ROLES:
        slot = "clinical_review"
    else:
        raise ManualGraphError(f"unsupported catalog reviewer role: {reviewer_role}")

    normalized_resolutions = _normalize_resolutions(
        resolutions or [], reviewer_id=reviewer_id, reviewer_role=reviewer_role
    )
    result = deepcopy(ledger)
    entry = next(item for item in result["decisions"] if item["recipe_version_id"] == recipe_version_id)
    entry[slot] = {
        "reviewer_id": reviewer_id,
        "reviewer_role": reviewer_role,
        "decision": decision,
        "comment": comment,
        "reviewed_at_utc": _timestamp(reviewed_at_utc),
    }
    if normalized_resolutions:
        existing = {item["item"]: item for item in entry["resolutions"]}
        for item in normalized_resolutions:
            existing[item["item"]] = item
        entry["resolutions"] = [existing[key] for key in sorted(existing)]
    return _sign_ledger(result)


def record_catalog_clinical_review(
    *,
    candidate_manifest: dict[str, Any],
    ledger: dict[str, Any],
    reviewer_name: str,
    reviewer_id: str,
    credentials: str,
    decision: str,
    notes: str | None = None,
    reviewed_at: str | None = None,
) -> dict[str, Any]:
    """Record the final catalog-level clinical decision after recipe-level review."""
    validate_catalog_review_ledger(candidate_manifest, ledger)
    if decision not in {"approved", "rejected"}:
        raise ManualGraphError("catalog clinical decision must be approved or rejected")
    result = deepcopy(ledger)
    result["clinical_review"] = {
        "reviewerName": _required_text(reviewer_name, "reviewer_name"),
        "reviewerId": _required_text(reviewer_id, "reviewer_id"),
        "credentials": _required_text(credentials, "credentials"),
        "reviewedAt": _timestamp(reviewed_at),
        "decision": decision,
        "notes": notes.strip() if isinstance(notes, str) and notes.strip() else None,
    }
    return _sign_ledger(result)


def catalog_review_status(
    *, candidate_manifest: dict[str, Any], candidate_evidence: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    """Return an auditable readiness summary without mutating the review ledger."""
    candidates = validate_catalog_review_ledger(candidate_manifest, ledger)
    raw_evidence = candidate_evidence.get("recipes")
    if not isinstance(raw_evidence, list):
        raise ManualGraphError("candidate recipe evidence must be an array")
    evidence_by_recipe: dict[str, dict[str, Any]] = {}
    for evidence in raw_evidence:
        if not isinstance(evidence, dict):
            raise ManualGraphError("candidate recipe evidence entries must be objects")
        version_id = _required_text(evidence.get("recipeVersionId"), "recipeVersionId")
        if version_id in evidence_by_recipe:
            raise ManualGraphError(f"candidate evidence repeats recipe version: {version_id}")
        evidence_by_recipe[version_id] = evidence
    if set(evidence_by_recipe) != set(candidates):
        raise ManualGraphError("candidate evidence must contain every recipe candidate exactly once")

    counts = {
        "data_approved": 0,
        "data_rejected": 0,
        "data_pending": 0,
        "clinical_approved": 0,
        "clinical_rejected": 0,
        "clinical_pending": 0,
    }
    unresolved_count = 0
    resolved_count = 0
    missing_resolution_count = 0
    clinical_recipe_reviewers: set[str] = set()
    for entry in ledger["decisions"]:
        for prefix, field in (("data", "data_review"), ("clinical", "clinical_review")):
            review = entry[field]
            if review is None:
                counts[f"{prefix}_pending"] += 1
            else:
                counts[f"{prefix}_{review['decision']}"] += 1
                if prefix == "clinical" and review["decision"] == "approved":
                    clinical_recipe_reviewers.add(review["reviewer_id"])
        expected = set(evidence_by_recipe[entry["recipe_version_id"]].get("unresolvedItems") or [])
        actual = {item["item"] for item in entry["resolutions"]}
        unresolved_count += len(expected)
        resolved_count += len(expected & actual)
        missing_resolution_count += len(expected - actual)

    final_review = ledger.get("clinical_review")
    final_decision = final_review.get("decision") if isinstance(final_review, dict) else None
    final_reviewer = final_review.get("reviewerId") if isinstance(final_review, dict) else None
    reviewer_bound = bool(final_reviewer) and final_reviewer in clinical_recipe_reviewers
    ready = (
        counts["data_approved"] == len(candidates)
        and counts["clinical_approved"] == len(candidates)
        and counts["data_rejected"] == 0
        and counts["clinical_rejected"] == 0
        and missing_resolution_count == 0
        and final_decision == "approved"
        and reviewer_bound
    )
    return {
        "schema_version": 1,
        "candidate_manifest_sha256": candidate_manifest["content_sha256"],
        "ledger_content_sha256": ledger["content_sha256"],
        "recipe_count": len(candidates),
        **counts,
        "unresolved_item_count": unresolved_count,
        "resolved_item_count": resolved_count,
        "missing_resolution_count": missing_resolution_count,
        "catalog_clinical_decision": final_decision,
        "catalog_clinical_reviewer_bound": reviewer_bound,
        "ready_for_finalize": ready,
    }


def validate_candidate_manifest(candidate_manifest: dict[str, Any]) -> dict[str, str]:
    if candidate_manifest.get("schema_version") != 1:
        raise ManualGraphError("candidate manifest schema_version must be 1")
    supplied_hash = candidate_manifest.get("content_sha256")
    unsigned = {key: value for key, value in candidate_manifest.items() if key != "content_sha256"}
    if supplied_hash != content_sha256(unsigned):
        raise ManualGraphError("candidate manifest content hash is invalid")
    raw_candidates = candidate_manifest.get("recipe_candidates")
    if not isinstance(raw_candidates, list) or not raw_candidates:
        raise ManualGraphError("candidate manifest has no recipe candidates")
    candidates: dict[str, str] = {}
    for candidate in raw_candidates:
        if not isinstance(candidate, dict):
            raise ManualGraphError("candidate manifest recipe entries must be objects")
        version_id = _required_text(candidate.get("recipe_version_id"), "recipe_version_id")
        digest = _required_text(candidate.get("candidate_sha256"), "candidate_sha256")
        if version_id in candidates:
            raise ManualGraphError(f"candidate manifest repeats recipe version: {version_id}")
        candidates[version_id] = digest
    return candidates


def validate_catalog_review_ledger(
    candidate_manifest: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, str]:
    candidates = validate_candidate_manifest(candidate_manifest)
    if ledger.get("schema_version") != 1:
        raise ManualGraphError("catalog review ledger schema_version must be 1")
    if ledger.get("candidate_manifest_sha256") != candidate_manifest.get("content_sha256"):
        raise ManualGraphError("catalog review ledger belongs to a different candidate manifest")
    supplied_hash = ledger.get("content_sha256")
    unsigned = {key: value for key, value in ledger.items() if key != "content_sha256"}
    if supplied_hash != content_sha256(unsigned):
        raise ManualGraphError("catalog review ledger content hash is invalid")
    decisions = ledger.get("decisions")
    if not isinstance(decisions, list):
        raise ManualGraphError("catalog review decisions must be an array")
    seen: set[str] = set()
    for entry in decisions:
        if not isinstance(entry, dict):
            raise ManualGraphError("catalog review decision entries must be objects")
        version_id = _required_text(entry.get("recipe_version_id"), "recipe_version_id")
        if version_id in seen:
            raise ManualGraphError(f"catalog review repeats recipe version: {version_id}")
        seen.add(version_id)
        if version_id not in candidates or entry.get("candidate_sha256") != candidates[version_id]:
            raise ManualGraphError(f"catalog review decision is stale or tampered: {version_id}")
        _validate_review(entry.get("data_review"), DATA_REVIEW_ROLES, allow_empty=True)
        _validate_review(entry.get("clinical_review"), CLINICAL_REVIEW_ROLES, allow_empty=True)
        _validate_resolution_records(entry.get("resolutions"))
    if seen != set(candidates):
        raise ManualGraphError("catalog review ledger must contain every recipe candidate exactly once")
    return candidates


def _validate_review(value: Any, roles: set[str], *, allow_empty: bool) -> None:
    if value is None and allow_empty:
        return
    if not isinstance(value, dict):
        raise ManualGraphError("catalog review record must be an object")
    if value.get("decision") not in {"approved", "rejected"}:
        raise ManualGraphError("catalog review record has an invalid decision")
    if value.get("reviewer_role") not in roles:
        raise ManualGraphError("catalog review record has an invalid reviewer role")
    for field in ("reviewer_id", "comment", "reviewed_at_utc"):
        _required_text(value.get(field), field)
    _validate_timestamp(value["reviewed_at_utc"])


def _normalize_resolutions(
    values: list[dict[str, str]], *, reviewer_id: str, reviewer_role: str
) -> list[dict[str, str]]:
    if not isinstance(values, list):
        raise ManualGraphError("resolutions must be an array")
    result: list[dict[str, str]] = []
    seen: set[str] = set()
    for value in values:
        if not isinstance(value, dict):
            raise ManualGraphError("resolution entries must be objects")
        item = _required_text(value.get("item"), "resolution item")
        if item in seen:
            raise ManualGraphError(f"resolutions repeat item: {item}")
        seen.add(item)
        result.append({
            "item": item,
            "resolution": _required_text(value.get("resolution"), "resolution"),
            "reviewer_id": reviewer_id,
            "reviewer_role": reviewer_role,
        })
    return result


def _validate_resolution_records(values: Any) -> None:
    if not isinstance(values, list):
        raise ManualGraphError("catalog review resolutions must be an array")
    seen: set[str] = set()
    for value in values:
        if not isinstance(value, dict):
            raise ManualGraphError("catalog review resolution must be an object")
        item = _required_text(value.get("item"), "resolution item")
        if item in seen:
            raise ManualGraphError(f"catalog review repeats resolution item: {item}")
        seen.add(item)
        _required_text(value.get("resolution"), "resolution")
        _required_text(value.get("reviewer_id"), "reviewer_id")
        role = _required_text(value.get("reviewer_role"), "reviewer_role")
        if role not in DATA_REVIEW_ROLES | CLINICAL_REVIEW_ROLES:
            raise ManualGraphError(f"unsupported resolution reviewer role: {role}")


def _sign_ledger(ledger: dict[str, Any]) -> dict[str, Any]:
    unsigned = {key: value for key, value in ledger.items() if key != "content_sha256"}
    return {**unsigned, "content_sha256": content_sha256(unsigned)}


def _timestamp(value: str | None) -> str:
    if value is None:
        return datetime.now(timezone.utc).isoformat()
    normalized = _required_text(value, "review timestamp")
    _validate_timestamp(normalized)
    return normalized


def _validate_timestamp(value: str) -> None:
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        raise ManualGraphError("review timestamp must be ISO-8601") from None
    if parsed.tzinfo is None:
        raise ManualGraphError("review timestamp must include a timezone")


def _required_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ManualGraphError(f"{label} is required")
    return value.strip()
