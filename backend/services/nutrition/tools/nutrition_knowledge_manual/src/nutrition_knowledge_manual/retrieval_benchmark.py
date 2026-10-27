from __future__ import annotations

import math
import platform
from time import perf_counter

from .errors import ManualGraphError
from .jsonio import content_sha256
from .retrieval_artifacts import code_identity, sign
from .retrieval_contract import validate_answerability_and_citations

STRATEGIES = ("keyword", "vector", "hybrid", "graph")
COVERAGE_TAGS = ("section_locator", "numbers_units", "insufficient_evidence", "multi_hop", "edition_conflict")


def validate_cases(cases: list[dict], chunks: list[dict], allowed_splits: set[str]) -> None:
    seen, questions = set(), set()
    eligible = {c["chunk_id"] for c in chunks}
    if not cases:
        raise ManualGraphError("benchmark requires cases")
    for case in cases:
        cid, question = case.get("case_id"), case.get("question")
        if not isinstance(cid, str) or not cid.strip() or cid in seen:
            raise ManualGraphError("benchmark case id is missing or duplicated")
        if not isinstance(question, str) or not question.strip() or len(question) > 500:
            raise ManualGraphError("benchmark question is invalid")
        fingerprint = " ".join(question.casefold().split())
        if fingerprint in questions:
            raise ManualGraphError("benchmark repeats a question")
        if case.get("split") not in allowed_splits:
            raise ManualGraphError("holdout must not be opened by a visible benchmark")
        tags = case.get("tags", [])
        if not isinstance(tags, list) or any(not isinstance(t, str) or not t for t in tags) or len(tags) != len(set(tags)):
            raise ManualGraphError("benchmark tags are invalid")
        validate_answerability_and_citations(item=case, eligible_ids=eligible,
                                            context="benchmark", case_id=cid)
        if "insufficient_evidence" in tags and case["answerability"] != "insufficient_evidence":
            raise ManualGraphError("insufficient_evidence tag requires an unanswerable case")
        if "multi_hop" in tags and len(case["relevant_chunk_ids"]) < 2:
            raise ManualGraphError("multi_hop case requires at least two evidence chunks")
        seen.add(cid)
        questions.add(fingerprint)


def validate_hits(hits: list[dict], chunks: dict[str, dict]) -> None:
    if not isinstance(hits, list) or len(hits) > 5:
        raise ManualGraphError("benchmark requires at most five cited hits")
    seen = set()
    for hit in hits:
        cid = hit.get("chunk_id")
        if cid not in chunks or cid in seen:
            raise ManualGraphError("retriever returned duplicate or ineligible evidence")
        if any(hit.get(k) != chunks[cid].get(k) for k in
               ("source_revision_id", "source_locator", "pdf_page", "printed_page")):
            raise ManualGraphError("retriever returned a fabricated citation")
        score = hit.get("score")
        if isinstance(score, bool) or not isinstance(score, (int, float)) or not math.isfinite(score):
            raise ManualGraphError("retriever returned an invalid score")
        seen.add(cid)


def metrics(rows: list[dict]) -> dict:
    answerable = [r for r in rows if r["answerability"] == "answerable"]
    insufficient = [r for r in rows if r["answerability"] == "insufficient_evidence"]
    recall1, recall5, reciprocal, ndcg = [], [], [], []
    for row in answerable:
        relevant = set(row["relevant_chunk_ids"])
        retrieved = [h["chunk_id"] for h in row["hits"]]
        recall1.append(len(relevant.intersection(retrieved[:1])) / len(relevant))
        recall5.append(len(relevant.intersection(retrieved[:5])) / len(relevant))
        rank = next((i for i, cid in enumerate(retrieved, 1) if cid in relevant), None)
        reciprocal.append(1 / rank if rank else 0)
        dcg = sum(1 / math.log2(i + 1) for i, cid in enumerate(retrieved[:5], 1) if cid in relevant)
        ideal = sum(1 / math.log2(i + 1) for i in range(1, min(5, len(relevant)) + 1))
        ndcg.append(dcg / ideal)
    average = lambda values: round(sum(values) / len(values), 6) if values else None
    latency = sorted(r["latency_ms"] for r in rows)
    percentile = lambda p: round(latency[max(0, math.ceil(len(latency) * p) - 1)], 3) if latency else None
    return {"case_count": len(rows), "answerable_case_count": len(answerable),
            "insufficient_evidence_count": len(insufficient),
            "recall_at_1": average(recall1), "recall_at_5": average(recall5),
            "mrr": average(reciprocal), "ndcg_at_5": average(ndcg),
            "abstention_accuracy": average([int(not r["hits"]) for r in insufficient]),
            "false_abstention_rate": average([int(not r["hits"]) for r in answerable]),
            "citation_integrity": 1.0, "ineligible_hit_count": 0,
            "latency_p50_ms": percentile(.5), "latency_p95_ms": percentile(.95)}


def summarize(rows: list[dict]) -> dict:
    return {"metrics": metrics(rows),
            "by_split": {s: metrics([r for r in rows if r["split"] == s]) for s in sorted({r["split"] for r in rows})},
            "by_tag": {t: metrics([r for r in rows if t in r["tags"]]) for t in sorted({t for r in rows for t in r["tags"]})}}


def evaluate_strategy(retriever, cases: list[dict], chunks: list[dict]) -> dict:
    lookup = {c["chunk_id"]: c for c in chunks}
    rows = []
    for case in cases:
        started = perf_counter()
        hits = retriever.search(case["question"], 5)
        elapsed = (perf_counter() - started) * 1000
        validate_hits(hits, lookup)
        rows.append({k: case.get(k, []) for k in
                     ("case_id", "split", "tags", "answerability", "relevant_chunk_ids")} |
                    {"hits": hits, "latency_ms": round(elapsed, 3)})
    return {"status": "evaluated", **summarize(rows), "results": rows}


def benchmark(*, cases: dict, chunks: list[dict], retrievers: dict, bindings: dict,
              holdout: bool = False) -> dict:
    frozen_code = code_identity()
    validate_cases(cases["cases"], chunks, {"holdout"} if holdout else {"development", "validation"})
    reports = {}
    names = sorted(retrievers) if holdout else STRATEGIES
    for name in names:
        retriever = retrievers.get(name)
        reports[name] = ({"status": "not_run", "reason": "required_artifacts_or_review_missing"}
                         if retriever is None else evaluate_strategy(retriever, cases["cases"], chunks))
    if code_identity() != frozen_code:
        raise ManualGraphError("retrieval code changed during benchmark; results are invalid")
    return sign({"schema_version": 1, "mode": "paired_retrieval_benchmark",
                 "dataset_kind": "holdout" if holdout else "visible",
                 "evaluation_sha256": content_sha256(cases), "bindings": bindings,
                 "code": frozen_code, "environment": {"python": platform.python_version(),
                    "platform": platform.platform(), "machine": platform.machine(),
                    "processor": platform.processor(), "latency_includes_query_encoding": True},
                 "strategies": reports, "release_ready": False})


def hard_gate_failures(report: dict, prefix: str) -> list[str]:
    failures = []
    values = report["metrics"]
    for key, minimum in (("recall_at_5", .90), ("abstention_accuracy", .90), ("citation_integrity", 1.0)):
        if values[key] is None or values[key] < minimum:
            failures.append(f"{prefix}.{key}_missing_or_below_gate")
    for tag in COVERAGE_TAGS:
        group = report["by_tag"].get(tag)
        if group is None:
            failures.append(f"{prefix}.missing_tag:{tag}")
        elif tag != "insufficient_evidence":
            if (group["answerable_case_count"] > 0
                    and (group["recall_at_5"] is None or group["recall_at_5"] < .80)):
                failures.append(f"{prefix}.risk_group_below_gate:{tag}")
            if (group["insufficient_evidence_count"] > 0
                    and (group["abstention_accuracy"] is None
                         or group["abstention_accuracy"] < .90)):
                failures.append(f"{prefix}.risk_group_abstention_below_gate:{tag}")
    return failures
