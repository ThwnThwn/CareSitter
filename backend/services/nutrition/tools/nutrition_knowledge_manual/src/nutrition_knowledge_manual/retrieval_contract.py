from __future__ import annotations

from typing import Any

from .errors import ManualGraphError


ANSWERABLE = "answerable"
INSUFFICIENT_EVIDENCE = "insufficient_evidence"
ANSWERABILITY_VALUES = {ANSWERABLE, INSUFFICIENT_EVIDENCE}


def validate_answerability_and_citations(
    *, item: dict[str, Any], eligible_ids: set[str], context: str, case_id: str
) -> tuple[str, list[str]]:
    answerability = item.get("answerability")
    if answerability not in ANSWERABILITY_VALUES:
        raise ManualGraphError(f"{context} answerability is invalid: {case_id}")

    citations = item.get("relevant_chunk_ids")
    if (
        not isinstance(citations, list)
        or any(not isinstance(chunk_id, str) or not chunk_id for chunk_id in citations)
        or len(citations) != len(set(citations))
    ):
        raise ManualGraphError(f"{context} citations are invalid: {case_id}")
    if answerability == ANSWERABLE and not citations:
        raise ManualGraphError(f"{context} answerable case requires citations: {case_id}")
    if answerability == INSUFFICIENT_EVIDENCE and citations:
        raise ManualGraphError(
            f"{context} insufficient_evidence case must not declare citations: {case_id}"
        )

    unknown = sorted(set(citations) - eligible_ids)
    if unknown:
        raise ManualGraphError(f"{context} cites unknown or ineligible chunks: {case_id}")
    return answerability, citations
