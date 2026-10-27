from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
import unicodedata

from .corpus_freeze import validate_retrieval_corpus_freeze_document
from .errors import ManualGraphError
from .jsonio import content_sha256
from .retrieval_contract import validate_answerability_and_citations


_CLINICAL_AUTHOR_ROLES = {"dietitian", "physician"}


def seal_independent_holdout(
    *,
    submission: dict[str, Any],
    corpus_freeze: dict[str, Any],
    visible_evaluations: list[dict[str, Any]],
    minimum_cases: int = 10,
) -> dict[str, Any]:
    """Seal a newly authored holdout manifest without evaluating or consuming it.

    The declaration is auditable evidence supplied by its author; code cannot turn a
    visible pilot into an independent clinical review. Exact question/citation pairs
    from named visible evaluations are rejected to prevent relabelling the pilot.
    """
    validate_retrieval_corpus_freeze_document(corpus_freeze)
    if minimum_cases < 10:
        raise ManualGraphError("independent holdout must require at least 10 cases")
    if not isinstance(submission, dict) or submission.get("schema_version") != 1:
        raise ManualGraphError("independent holdout submission schema_version must be 1")
    if submission.get("dataset_kind") != "independent_holdout_submission":
        raise ManualGraphError("only a new independent holdout submission can be sealed")
    if submission.get("holdout_status") != "pending_seal":
        raise ManualGraphError("independent holdout submission must be pending_seal")
    _validate_corpus_binding(submission=submission, corpus_freeze=corpus_freeze)
    _validate_independence_attestation(submission.get("independence"))
    cases = _validate_holdout_cases(
        cases=submission.get("cases"), corpus_freeze=corpus_freeze, minimum_cases=minimum_cases
    )
    visible_fingerprints = _visible_case_fingerprints(visible_evaluations)
    visible_questions = {_question_key(case["question"]) for evaluation in visible_evaluations
                         for case in evaluation["cases"]}
    reused = sorted(_case_fingerprint(case) for case in cases if _case_fingerprint(case) in visible_fingerprints)
    if reused or any(_question_key(case["question"]) in visible_questions for case in cases):
        raise ManualGraphError("independent holdout reuses a visible evaluation question and citation pair")

    submission_hash = content_sha256(submission)
    sealed = {
        "schema_version": 1,
        "mode": "sealed_independent_retrieval_holdout",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "holdout_submission_content_sha256": submission_hash,
        "holdout_case_set_sha256": content_sha256(sorted(_case_fingerprint(case) for case in cases)),
        "case_count": len(cases),
        "consumption_state": "sealed_not_consumed",
        "release_ready": False,
    }
    return _sign(sealed)


def validate_sealed_independent_holdout(
    *, sealed_holdout: dict[str, Any], submission: dict[str, Any], corpus_freeze: dict[str, Any]
) -> dict[str, Any]:
    """Verify the marker still binds the exact unconsumed independent submission."""
    validate_retrieval_corpus_freeze_document(corpus_freeze)
    if sealed_holdout.get("schema_version") != 1:
        raise ManualGraphError("sealed holdout schema_version must be 1")
    if sealed_holdout.get("mode") != "sealed_independent_retrieval_holdout":
        raise ManualGraphError("sealed holdout mode is invalid")
    if sealed_holdout.get("consumption_state") != "sealed_not_consumed":
        raise ManualGraphError("sealed holdout has already been consumed")
    if sealed_holdout.get("release_ready") is not False:
        raise ManualGraphError("sealed holdout must not declare release_ready")
    unsigned = {
        key: value for key, value in sealed_holdout.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    if sealed_holdout.get("content_sha256") != content_sha256(unsigned):
        raise ManualGraphError("sealed holdout content hash is invalid")
    if sealed_holdout.get("corpus_freeze_sha256") != corpus_freeze.get("content_sha256"):
        raise ManualGraphError("sealed holdout belongs to a different corpus freeze")
    if sealed_holdout.get("holdout_submission_content_sha256") != content_sha256(submission):
        raise ManualGraphError("sealed holdout submission is stale or tampered")
    _validate_corpus_binding(submission=submission, corpus_freeze=corpus_freeze)
    _validate_independence_attestation(submission.get("independence"))
    cases = _validate_holdout_cases(
        cases=submission.get("cases"), corpus_freeze=corpus_freeze, minimum_cases=10
    )
    expected_case_set_hash = content_sha256(sorted(_case_fingerprint(case) for case in cases))
    if sealed_holdout.get("holdout_case_set_sha256") != expected_case_set_hash:
        raise ManualGraphError("sealed holdout case set is stale or tampered")
    if sealed_holdout.get("case_count") != len(cases):
        raise ManualGraphError("sealed holdout case count mismatch")
    return sealed_holdout


def _validate_corpus_binding(*, submission: dict[str, Any], corpus_freeze: dict[str, Any]) -> None:
    corpus = submission.get("corpus")
    if not isinstance(corpus, dict):
        raise ManualGraphError("independent holdout corpus binding is required")
    expected = {
        "source_revision_id": corpus_freeze["source_revision_id"],
        "chunks_sha256": corpus_freeze["chunks_sha256"],
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
    }
    if any(corpus.get(key) != value for key, value in expected.items()):
        raise ManualGraphError("independent holdout is bound to a different corpus freeze")


def _validate_independence_attestation(value: Any) -> None:
    if not isinstance(value, dict):
        raise ManualGraphError("independent holdout attestation is required")
    author_id = value.get("author_id")
    if not isinstance(author_id, str) or not author_id.strip():
        raise ManualGraphError("independent holdout author_id is required")
    if value.get("author_role") not in _CLINICAL_AUTHOR_ROLES:
        raise ManualGraphError("independent holdout author must be a dietitian or physician")
    if value.get("independently_authored") is not True:
        raise ManualGraphError("independent holdout requires an independently_authored attestation")
    note = value.get("attestation_note")
    if not isinstance(note, str) or not note.strip():
        raise ManualGraphError("independent holdout attestation_note is required")


def _validate_holdout_cases(
    *, cases: Any, corpus_freeze: dict[str, Any], minimum_cases: int
) -> list[dict[str, Any]]:
    if not isinstance(cases, list) or len(cases) < minimum_cases:
        raise ManualGraphError(f"independent holdout requires at least {minimum_cases} cases")
    eligible_ids = {
        item["chunk_id"] for item in corpus_freeze["eligible_chunk_identities"]
    }
    seen: set[str] = set()
    questions: set[str] = set()
    for case in cases:
        if not isinstance(case, dict):
            raise ManualGraphError("independent holdout case must be an object")
        case_id = case.get("case_id")
        if not isinstance(case_id, str) or not case_id.strip() or case_id in seen:
            raise ManualGraphError("independent holdout case_id is invalid or repeated")
        seen.add(case_id)
        question = case.get("question")
        if not isinstance(question, str) or not question.strip() or len(question) > 500:
            raise ManualGraphError(f"independent holdout question is invalid: {case_id}")
        key = _question_key(question)
        if key in questions:
            raise ManualGraphError("independent holdout repeats a question")
        questions.add(key)
        if case.get("split") != "holdout":
            raise ManualGraphError("independent holdout cases must use the holdout split")
        validate_answerability_and_citations(
            item=case,
            eligible_ids=eligible_ids,
            context="independent holdout",
            case_id=case_id,
        )
    return cases


def _visible_case_fingerprints(evaluations: list[dict[str, Any]]) -> set[str]:
    if not isinstance(evaluations, list):
        raise ManualGraphError("visible evaluations must be an array")
    result: set[str] = set()
    for evaluation in evaluations:
        if not isinstance(evaluation, dict):
            raise ManualGraphError("visible evaluation must be an object")
        cases = evaluation.get("cases")
        if not isinstance(cases, list):
            raise ManualGraphError("visible evaluation cases must be an array")
        for case in cases:
            if not isinstance(case, dict):
                raise ManualGraphError("visible evaluation case must be an object")
            if (
                not isinstance(case.get("question"), str)
                or not isinstance(case.get("relevant_chunk_ids"), list)
                or not isinstance(case.get("answerability"), str)
            ):
                raise ManualGraphError("visible evaluation case is invalid")
            result.add(_case_fingerprint(case))
    return result


def case_fingerprint(case: dict[str, Any], source_revision_id: str | None = None) -> str:
    """Fingerprint a case; the visible registry binds the source revision, holdout sealing does not."""
    payload = {
        "question": _question_key(case["question"]),
        "answerability": case["answerability"],
        "relevant_chunk_ids": sorted(case["relevant_chunk_ids"]),
    }
    if source_revision_id is not None:
        payload["source_revision_id"] = source_revision_id
    return content_sha256(payload)


def _case_fingerprint(case: dict[str, Any]) -> str:
    return case_fingerprint(case)


def _question_key(question: str) -> str:
    return " ".join(unicodedata.normalize("NFC", question).casefold().split())


def _sign(value: dict[str, Any]) -> dict[str, Any]:
    unsigned = {
        key: item for key, item in value.items()
        if key not in {"created_at_utc", "content_sha256"}
    }
    return {**value, "content_sha256": content_sha256(unsigned)}
