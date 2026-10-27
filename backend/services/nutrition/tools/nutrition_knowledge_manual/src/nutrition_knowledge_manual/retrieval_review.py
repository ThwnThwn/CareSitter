from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
import re
from typing import Any

from .corpus_freeze import (
    validate_retrieval_corpus_binding,
    validate_retrieval_corpus_freeze_document,
)
from .errors import ManualGraphError
from .jsonio import content_sha256
from .retrieval_eval import load_retrieval_chunks
from .retrieval_contract import validate_answerability_and_citations


DATA_REVIEW_ROLES = {"data_steward"}
CLINICAL_REVIEW_ROLES = {"dietitian", "physician"}
_QUOTED_TEXT = re.compile(r"[“\"]([^”\"]+)[”\"]")
_HEADING_PREFIX = re.compile(r"^(?:[IVXLCDM]+|\d+(?:\.\d+)*)\.?\s+", re.IGNORECASE)


def _evidence_preview(*, text: str, question: str, limit: int) -> str:
    """Select a bounded excerpt around the most specific cited heading in the question."""
    candidates: list[str] = []
    for quoted in _QUOTED_TEXT.findall(question):
        candidates.extend(part.strip() for part in re.split(r"\s+[—–]\s+", quoted) if part.strip())
        candidates.append(quoted.strip())

    folded = text.casefold()
    matches: list[tuple[tuple[int, int, int], int]] = []
    for candidate in candidates:
        position = folded.find(candidate.casefold())
        if position < 0:
            continue
        prefix = _HEADING_PREFIX.match(candidate)
        depth = len(prefix.group(0).strip().rstrip(".").split(".")) if prefix else 0
        matches.append(((depth, int(any(char.isalpha() for char in candidate)), len(candidate)), position))

    start = max(matches, default=((0, 0, 0), 0))[1]
    end = min(len(text), start + limit)
    if end < len(text):
        word_boundary = text.rfind(" ", start, end)
        if word_boundary > start:
            end = word_boundary
    return text[start:end].strip()


def empty_retrieval_review(*, cases: dict[str, Any], corpus_freeze: dict[str, Any]) -> dict[str, Any]:
    """Initialize one two-role, hash-bound review record for every visible case."""
    case_hashes = _validate_evaluation_cases(cases=cases, corpus_freeze=corpus_freeze)
    ledger = {
        "schema_version": 1,
        "mode": "local_retrieval_evaluation_review_ledger",
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "evaluation_content_sha256": _evaluation_content_sha256(cases),
        "decisions": [
            {
                "case_id": case_id,
                "case_content_sha256": case_hashes[case_id],
                "source_locator_review": None,
                "clinical_relevance_review": None,
            }
            for case_id in sorted(case_hashes)
        ],
    }
    return _sign_ledger(ledger)


def record_retrieval_case_review(
    *,
    cases: dict[str, Any],
    corpus_freeze: dict[str, Any],
    ledger: dict[str, Any],
    case_id: str,
    decision: str,
    reviewer_id: str,
    reviewer_role: str,
    comment: str,
    reviewed_at_utc: str | None = None,
) -> dict[str, Any]:
    """Record the review that the caller's role is permitted to make for one case."""
    case_hashes = validate_retrieval_review_ledger(
        cases=cases, corpus_freeze=corpus_freeze, ledger=ledger
    )
    if case_id not in case_hashes:
        raise ManualGraphError(f"retrieval evaluation case does not exist: {case_id}")
    if decision not in {"approved", "rejected"}:
        raise ManualGraphError("retrieval review decision must be approved or rejected")
    if reviewer_role in DATA_REVIEW_ROLES:
        slot = "source_locator_review"
    elif reviewer_role in CLINICAL_REVIEW_ROLES:
        slot = "clinical_relevance_review"
    else:
        raise ManualGraphError(f"unsupported retrieval reviewer role: {reviewer_role}")

    result = deepcopy(ledger)
    entry = next(item for item in result["decisions"] if item["case_id"] == case_id)
    entry[slot] = {
        "reviewer_id": _required_text(reviewer_id, "reviewer_id"),
        "reviewer_role": reviewer_role,
        "decision": decision,
        "comment": _required_text(comment, "comment"),
        "reviewed_at_utc": _timestamp(reviewed_at_utc),
    }
    return _sign_ledger(result)


def validate_retrieval_review_ledger(
    *, cases: dict[str, Any], corpus_freeze: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, str]:
    """Fail closed if the corpus, evaluation cases, or individual reviews changed."""
    case_hashes = _validate_evaluation_cases(cases=cases, corpus_freeze=corpus_freeze)
    if ledger.get("schema_version") != 1:
        raise ManualGraphError("retrieval review ledger schema_version must be 1")
    if ledger.get("mode") != "local_retrieval_evaluation_review_ledger":
        raise ManualGraphError("retrieval review ledger mode is invalid")
    if ledger.get("corpus_freeze_sha256") != corpus_freeze.get("content_sha256"):
        raise ManualGraphError("retrieval review ledger belongs to a different corpus freeze")
    if ledger.get("evaluation_content_sha256") != _evaluation_content_sha256(cases):
        raise ManualGraphError("retrieval review ledger belongs to a different evaluation set")
    _validate_ledger_hash(ledger)
    decisions = ledger.get("decisions")
    if not isinstance(decisions, list):
        raise ManualGraphError("retrieval review decisions must be an array")
    seen: set[str] = set()
    for entry in decisions:
        if not isinstance(entry, dict):
            raise ManualGraphError("retrieval review decision entry must be an object")
        case_id = _required_text(entry.get("case_id"), "case_id")
        if case_id in seen:
            raise ManualGraphError(f"retrieval review ledger repeats case: {case_id}")
        seen.add(case_id)
        if case_id not in case_hashes or entry.get("case_content_sha256") != case_hashes[case_id]:
            raise ManualGraphError(f"retrieval review decision is stale or tampered: {case_id}")
        _validate_review(entry.get("source_locator_review"), DATA_REVIEW_ROLES)
        _validate_review(entry.get("clinical_relevance_review"), CLINICAL_REVIEW_ROLES)
    if seen != set(case_hashes):
        raise ManualGraphError("retrieval review ledger must contain every evaluation case exactly once")
    return case_hashes


def retrieval_review_status(
    *, cases: dict[str, Any], corpus_freeze: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    """Summarize review progress. This never changes an evaluation set's release state."""
    case_hashes = validate_retrieval_review_ledger(
        cases=cases, corpus_freeze=corpus_freeze, ledger=ledger
    )
    counts = {
        "source_locator_approved": 0,
        "source_locator_rejected": 0,
        "source_locator_pending": 0,
        "clinical_relevance_approved": 0,
        "clinical_relevance_rejected": 0,
        "clinical_relevance_pending": 0,
    }
    for entry in ledger["decisions"]:
        for prefix, field in (
            ("source_locator", "source_locator_review"),
            ("clinical_relevance", "clinical_relevance_review"),
        ):
            review = entry[field]
            key = f"{prefix}_{'pending' if review is None else review['decision']}"
            counts[key] += 1
    all_approved = (
        counts["source_locator_approved"] == len(case_hashes)
        and counts["clinical_relevance_approved"] == len(case_hashes)
    )
    return {
        "schema_version": 1,
        "mode": "local_retrieval_evaluation_review_status",
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "evaluation_content_sha256": _evaluation_content_sha256(cases),
        "ledger_content_sha256": ledger["content_sha256"],
        "case_count": len(case_hashes),
        **counts,
        "all_cases_approved": all_approved,
        "release_ready": False,
        "release_blockers": [
            "review_ledger_is_not_a_sealed_independent_gold_holdout",
            "retrieval_strategy_and_release_manifest_are_not_frozen",
        ],
    }


def build_retrieval_review_packet(
    *,
    cases: dict[str, Any],
    corpus_freeze: dict[str, Any],
    chunks_path: Path,
    preview_characters: int = 600,
) -> dict[str, Any]:
    """Build a bounded local packet; only frozen, eligible cited chunks are disclosed."""
    if not 120 <= preview_characters <= 1000:
        raise ManualGraphError("review packet preview_characters must be between 120 and 1000")
    case_hashes = _validate_evaluation_cases(cases=cases, corpus_freeze=corpus_freeze)
    validate_retrieval_corpus_binding(corpus_freeze=corpus_freeze, chunks_path=chunks_path)
    chunks = {item["chunk_id"]: item for item in load_retrieval_chunks(chunks_path)}
    packet_cases = []
    for case in sorted(cases["cases"], key=lambda item: item["case_id"]):
        citations = []
        for chunk_id in case["relevant_chunk_ids"]:
            chunk = chunks.get(chunk_id)
            if chunk is None:
                raise ManualGraphError(f"review packet cites unknown or ineligible chunk: {chunk_id}")
            preview = _evidence_preview(
                text=chunk["text"], question=case["question"], limit=preview_characters,
            )
            citations.append({
                "chunk_id": chunk_id,
                "text_sha256": chunk["text_sha256"],
                "source_revision_id": chunk["source_revision_id"],
                "source_locator": chunk["source_locator"],
                "pdf_page": chunk.get("pdf_page"),
                "printed_page": chunk.get("printed_page"),
                "headings": chunk.get("headings") or [],
                "text_preview": preview,
                "text_preview_truncated": len(preview) < len(chunk["text"]),
            })
        packet_cases.append({
            "case_id": case["case_id"],
            "case_content_sha256": case_hashes[case["case_id"]],
            "question": case["question"],
            "split": case["split"],
            "answerability": case["answerability"],
            "tags": case.get("tags") or [],
            "candidate_citations": citations,
        })
    packet = {
        "schema_version": 1,
        "mode": "local_retrieval_review_packet",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "evaluation_content_sha256": _evaluation_content_sha256(cases),
        "preview_characters": preview_characters,
        "case_count": len(packet_cases),
        "cases": packet_cases,
    }
    return _sign_packet(packet)


def _validate_evaluation_cases(*, cases: dict[str, Any], corpus_freeze: dict[str, Any]) -> dict[str, str]:
    validate_retrieval_corpus_freeze_document(corpus_freeze)
    if not isinstance(cases, dict) or cases.get("schema_version") != 1:
        raise ManualGraphError("retrieval evaluation schema_version must be 1")
    corpus = cases.get("corpus")
    if not isinstance(corpus, dict):
        raise ManualGraphError("retrieval evaluation corpus binding is required")
    if corpus.get("chunks_sha256") != corpus_freeze.get("chunks_sha256"):
        raise ManualGraphError("retrieval evaluation is bound to a different chunk artifact")
    if corpus.get("source_revision_id") != corpus_freeze.get("source_revision_id"):
        raise ManualGraphError("retrieval evaluation source revision does not match the corpus freeze")
    if corpus.get("corpus_freeze_sha256") != corpus_freeze.get("content_sha256"):
        raise ManualGraphError("retrieval evaluation is bound to a different corpus freeze")
    items = cases.get("cases")
    if not isinstance(items, list) or not items:
        raise ManualGraphError("retrieval evaluation has no cases")
    eligible_ids = {
        item["chunk_id"] for item in corpus_freeze.get("eligible_chunk_identities") or []
        if isinstance(item, dict) and isinstance(item.get("chunk_id"), str)
    }
    result: dict[str, str] = {}
    for item in items:
        if not isinstance(item, dict):
            raise ManualGraphError("retrieval evaluation case must be an object")
        case_id = _required_text(item.get("case_id"), "case_id")
        if case_id in result:
            raise ManualGraphError(f"retrieval evaluation repeats case: {case_id}")
        _required_text(item.get("question"), "question")
        if item.get("split") not in {"development", "validation", "holdout"}:
            raise ManualGraphError(f"retrieval evaluation split is invalid: {case_id}")
        validate_answerability_and_citations(
            item=item,
            eligible_ids=eligible_ids,
            context="retrieval evaluation",
            case_id=case_id,
        )
        result[case_id] = content_sha256(item)
    return result


def _evaluation_content_sha256(cases: dict[str, Any]) -> str:
    return content_sha256(cases)


def _validate_ledger_hash(ledger: dict[str, Any]) -> None:
    unsigned = {key: value for key, value in ledger.items() if key != "content_sha256"}
    if ledger.get("content_sha256") != content_sha256(unsigned):
        raise ManualGraphError("retrieval review ledger content hash is invalid")


def _validate_review(value: Any, roles: set[str]) -> None:
    if value is None:
        return
    if not isinstance(value, dict):
        raise ManualGraphError("retrieval review record must be an object")
    if value.get("decision") not in {"approved", "rejected"}:
        raise ManualGraphError("retrieval review record has an invalid decision")
    if value.get("reviewer_role") not in roles:
        raise ManualGraphError("retrieval review record has an invalid reviewer role")
    for field in ("reviewer_id", "comment", "reviewed_at_utc"):
        _required_text(value.get(field), field)
    _validate_timestamp(value["reviewed_at_utc"])


def _sign_ledger(ledger: dict[str, Any]) -> dict[str, Any]:
    unsigned = {key: value for key, value in ledger.items() if key != "content_sha256"}
    return {**unsigned, "content_sha256": content_sha256(unsigned)}


def _sign_packet(packet: dict[str, Any]) -> dict[str, Any]:
    unsigned = {
        key: value for key, value in packet.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    return {**packet, "content_sha256": content_sha256(unsigned)}


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
