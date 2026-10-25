from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
from typing import Any

from .corpus_freeze import validate_retrieval_corpus_binding
from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json
from .keyword_retriever import _LexicalIndex
from .retrieval_contract import (
    ANSWERABLE,
    INSUFFICIENT_EVIDENCE,
    validate_answerability_and_citations,
)


_SPLITS = {"development", "validation", "holdout"}
_CLINICAL_REVIEWER_ROLES = {"dietitian", "physician"}


def load_retrieval_chunks(path: Path) -> list[dict[str, Any]]:
    chunks: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    with path.open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, start=1):
            try:
                chunk = json.loads(line)
            except json.JSONDecodeError as error:
                raise ManualGraphError(f"invalid chunk JSON at line {line_number}") from error
            if not isinstance(chunk, dict):
                raise ManualGraphError(f"chunk must be an object at line {line_number}")
            chunk_id = chunk.get("chunk_id")
            if not isinstance(chunk_id, str) or not chunk_id:
                raise ManualGraphError(f"chunk_id is missing at line {line_number}")
            if chunk_id in seen_ids:
                raise ManualGraphError(f"chunk file repeats id: {chunk_id}")
            seen_ids.add(chunk_id)
            if chunk.get("index_eligible") is True:
                if chunk.get("review_status") != "ready_for_retrieval_eval":
                    raise ManualGraphError(f"eligible chunk has an invalid review status: {chunk_id}")
                if not str(chunk.get("text") or "").strip():
                    raise ManualGraphError(f"eligible chunk has no text: {chunk_id}")
                chunks.append(chunk)
    if not chunks:
        raise ManualGraphError("chunk file has no retrieval-eligible content")
    return chunks


def validate_retrieval_eval(
    *,
    cases: dict[str, Any],
    chunks_path: Path,
    chunks: list[dict[str, Any]],
    minimum_cases: int = 30,
    corpus_freeze: dict[str, Any],
) -> dict[str, Any]:
    if not isinstance(corpus_freeze, dict):
        raise ManualGraphError("retrieval evaluation requires a corpus freeze")
    if cases.get("schema_version") != 1:
        raise ManualGraphError("retrieval evaluation schema_version must be 1")
    dataset_status = cases.get("status")
    if dataset_status not in {
        "pilot_visible",
        "candidate_requires_independent_clinical_review",
        "reviewed_gold",
    }:
        raise ManualGraphError("retrieval evaluation dataset status is invalid")
    holdout_status = cases.get("holdout_status")
    expected_holdout_status = {
        "pilot_visible": "not_created",
        "candidate_requires_independent_clinical_review": "candidate_visible",
        "reviewed_gold": "sealed_independent",
    }[dataset_status]
    if holdout_status != expected_holdout_status:
        raise ManualGraphError("retrieval evaluation holdout status is invalid")
    corpus = cases.get("corpus") or {}
    chunks_sha256 = file_sha256(chunks_path)
    if corpus.get("chunks_sha256") != chunks_sha256:
        raise ManualGraphError("retrieval evaluation is bound to a different chunk artifact")

    revision_ids = {str(chunk.get("source_revision_id") or "") for chunk in chunks}
    if len(revision_ids) != 1 or "" in revision_ids:
        raise ManualGraphError("retrieval evaluation currently requires exactly one source revision")
    source_revision_id = next(iter(revision_ids))
    if corpus.get("source_revision_id") != source_revision_id:
        raise ManualGraphError("retrieval evaluation source revision does not match the chunks")
    validate_retrieval_corpus_binding(corpus_freeze=corpus_freeze, chunks_path=chunks_path)
    if corpus.get("corpus_freeze_sha256") != corpus_freeze.get("content_sha256"):
        raise ManualGraphError("retrieval evaluation is bound to a different corpus freeze")

    items = cases.get("cases")
    if not isinstance(items, list) or len(items) < minimum_cases:
        raise ManualGraphError(f"retrieval evaluation requires at least {minimum_cases} cases")
    eligible_ids = {chunk["chunk_id"] for chunk in chunks}
    seen_case_ids: set[str] = set()
    split_counts = Counter()
    answerability_counts = Counter()
    reviewed_count = 0
    for item in items:
        if not isinstance(item, dict):
            raise ManualGraphError("every retrieval evaluation case must be an object")
        case_id = item.get("case_id")
        if not isinstance(case_id, str) or not case_id.strip() or case_id in seen_case_ids:
            raise ManualGraphError(f"retrieval evaluation has an invalid or repeated case_id: {case_id}")
        seen_case_ids.add(case_id)
        question = item.get("question")
        if not isinstance(question, str) or not question.strip() or len(question) > 500:
            raise ManualGraphError(f"retrieval evaluation question is invalid: {case_id}")
        split = item.get("split")
        if split not in _SPLITS:
            raise ManualGraphError(f"retrieval evaluation split is invalid: {case_id}")
        split_counts[split] += 1
        answerability, _ = validate_answerability_and_citations(
            item=item,
            eligible_ids=eligible_ids,
            context="retrieval evaluation",
            case_id=case_id,
        )
        answerability_counts[answerability] += 1
        review_status = item.get("review_status")
        if review_status not in {"candidate", "reviewed"}:
            raise ManualGraphError(f"retrieval evaluation review status is invalid: {case_id}")
        if review_status == "reviewed":
            review = item.get("review") or {}
            if (
                review.get("reviewer_role") not in _CLINICAL_REVIEWER_ROLES
                or not str(review.get("reviewer_id") or "").strip()
                or not str(review.get("comment") or "").strip()
            ):
                raise ManualGraphError(f"retrieval evaluation review is incomplete: {case_id}")
            reviewed_count += 1
    if dataset_status == "pilot_visible":
        if set(split_counts) != {"development", "validation"}:
            raise ManualGraphError("visible pilot evaluation must contain only development and validation cases")
    elif set(split_counts) != _SPLITS:
        raise ManualGraphError("retrieval evaluation must contain development, validation and holdout cases")

    return {
        "schema_version": 1,
        "source_revision_id": source_revision_id,
        "chunks_sha256": chunks_sha256,
        "eligible_chunk_count": len(chunks),
        "case_count": len(items),
        "reviewed_case_count": reviewed_count,
        "candidate_case_count": len(items) - reviewed_count,
        "split_counts": dict(sorted(split_counts.items())),
        "answerability_counts": dict(sorted(answerability_counts.items())),
        "embedded_review_claim_count": reviewed_count,
        "review_complete": False,
        "dataset_status": dataset_status,
        "holdout_status": holdout_status,
        "evaluation_content_sha256": content_sha256(cases),
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "gold_ready": False,
    }

def run_retrieval_eval(
    *,
    cases: dict[str, Any],
    chunks_path: Path,
    top_k: int = 5,
    minimum_cases: int = 30,
    corpus_freeze: dict[str, Any],
) -> dict[str, Any]:
    if top_k < 1 or top_k > 20:
        raise ManualGraphError("top_k must be between 1 and 20")
    chunks = load_retrieval_chunks(chunks_path)
    validation = validate_retrieval_eval(
        cases=cases,
        chunks_path=chunks_path,
        chunks=chunks,
        minimum_cases=minimum_cases,
        corpus_freeze=corpus_freeze,
    )
    index = _LexicalIndex(chunks)
    results = []
    for item in cases["cases"]:
        hits = index.search(item["question"], top_k=top_k)
        relevant = set(item["relevant_chunk_ids"])
        first_relevant_rank = next(
            (rank for rank, hit in enumerate(hits, start=1) if hit["chunk_id"] in relevant), None
        )
        results.append({
            "case_id": item["case_id"],
            "split": item["split"],
            "review_status": item["review_status"],
            "answerability": item["answerability"],
            "relevant_chunk_ids": item["relevant_chunk_ids"],
            "first_relevant_rank": first_relevant_rank,
            "abstained": not hits,
            "hits": hits,
        })

    metrics = _metrics(results)
    by_split = {
        split: _metrics([item for item in results if item["split"] == split])
        for split in sorted(validation["split_counts"])
    }
    gate_failures = []
    if not validation["gold_ready"]:
        gate_failures.append("cases.require_independent_clinical_review")
    gate_failures.append("release.requires_review_ledger_sealed_holdout_paired_benchmark_and_manifest")
    if top_k != 5:
        gate_failures.append("evaluation.release_gate_requires_top_k_5")
    if metrics["recall_at_k"] is None or metrics["recall_at_k"] < 0.90:
        gate_failures.append("metrics.recall_at_5_below_0_90")
    if metrics["citation_integrity"] != 1.0:
        gate_failures.append("metrics.citation_integrity_below_1_00")
    if (
        metrics["abstention_accuracy"] is None
        or metrics["abstention_accuracy"] < 0.90
    ):
        gate_failures.append("metrics.abstention_accuracy_below_0_90")

    report = {
        "schema_version": 1,
        "mode": "local_keyword_retrieval_evaluation_only",
        "retrieval_strategy": "bm25_fielded_unicode_v1",
        "generation_enabled": False,
        "top_k": top_k,
        "validation": validation,
        "metrics": metrics,
        "metrics_by_split": by_split,
        "release_ready": False,
        "gate_failures": gate_failures,
        "results": results,
    }
    report["content_sha256"] = content_sha256(report)
    return report


def _metrics(results: list[dict[str, Any]]) -> dict[str, Any]:
    if not results:
        return {
            "case_count": 0,
            "answerable_case_count": 0,
            "insufficient_evidence_count": 0,
            "hit_count": 0,
            "recall_at_k": 0.0,
            "mrr": 0.0,
            "abstained_correct_count": 0,
            "abstention_accuracy": None,
            "citation_integrity": 1.0,
        }
    answerable = [item for item in results if item["answerability"] == ANSWERABLE]
    insufficient = [
        item for item in results if item["answerability"] == INSUFFICIENT_EVIDENCE
    ]
    ranks = [item["first_relevant_rank"] for item in answerable]
    hit_count = sum(rank is not None for rank in ranks)
    abstained_correct_count = sum(item["abstained"] for item in insufficient)
    citations_valid = all(
        hit.get("chunk_id") and hit.get("source_revision_id") and hit.get("source_locator")
        for item in results for hit in item["hits"]
    )
    return {
        "case_count": len(results),
        "answerable_case_count": len(answerable),
        "insufficient_evidence_count": len(insufficient),
        "hit_count": hit_count,
        "recall_at_k": round(sum(
            len(set(item["relevant_chunk_ids"]) & {hit["chunk_id"] for hit in item["hits"]})
            / len(item["relevant_chunk_ids"]) for item in answerable
        ) / len(answerable), 6) if answerable else None,
        "mrr": (
            round(sum(1 / rank for rank in ranks if rank is not None) / len(answerable), 6)
            if answerable else None
        ),
        "abstained_correct_count": abstained_correct_count,
        "abstention_accuracy": (
            round(abstained_correct_count / len(insufficient), 6) if insufficient else None
        ),
        "citation_integrity": 1.0 if citations_valid else 0.0,
    }
