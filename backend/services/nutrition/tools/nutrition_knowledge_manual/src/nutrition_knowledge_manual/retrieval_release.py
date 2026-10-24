from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from .errors import ManualGraphError
from .jsonio import content_sha256, load_json, write_json
from .retrieval_artifacts import code_identity, local_path, sign, verify, write_once
from .retrieval_benchmark import (COVERAGE_TAGS, STRATEGIES, benchmark, hard_gate_failures,
                                  summarize, validate_cases, validate_hits)
from .retrieval_holdout import seal_independent_holdout, validate_sealed_independent_holdout
from .retrieval_review import retrieval_review_status


def validate_report(report: dict, cases: dict, chunks: list[dict], bindings: dict) -> None:
    verify(report, "paired_retrieval_benchmark")
    if (report.get("bindings") != bindings or report.get("evaluation_sha256") != content_sha256(cases)
            or report.get("code") != code_identity()):
        raise ManualGraphError("benchmark is stale: code, config, corpus or evaluation changed")
    lookup = {c["chunk_id"]: c for c in chunks}
    expected = {c["case_id"]: c for c in cases["cases"]}
    for strategy in report["strategies"].values():
        if strategy.get("status") not in {"evaluated", "not_run"}:
            raise ManualGraphError("benchmark strategy status is invalid")
        if strategy.get("status") == "not_run":
            continue
        rows = strategy.get("results", [])
        if len(rows) != len(expected) or {r["case_id"] for r in rows} != set(expected):
            raise ManualGraphError("benchmark results do not cover every case")
        for row in rows:
            original = expected[row["case_id"]]
            if any(row[k] != original.get(k, []) for k in
                   ("split", "tags", "answerability", "relevant_chunk_ids")):
                raise ManualGraphError("benchmark results changed evaluation labels")
            validate_hits(row["hits"], lookup)
            if not isinstance(row["latency_ms"], (float, int)) or not 0 <= row["latency_ms"] < 3600000:
                raise ManualGraphError("benchmark latency is invalid")
        if any(strategy.get(k) != v for k, v in summarize(rows).items()):
            raise ManualGraphError("benchmark metrics do not match its results")


def review_failures(cases: dict, corpus_freeze: dict, ledger: dict, developers: list[str],
                    minimum: int, coverage: int) -> list[str]:
    status = retrieval_review_status(cases=cases, corpus_freeze=corpus_freeze, ledger=ledger)
    failures = []
    if len(cases["cases"]) < minimum:
        failures.append("review.insufficient_case_count")
    if not status["all_cases_approved"]:
        failures.append("review.pending_or_rejected")
    for entry in ledger["decisions"]:
        source, clinical = entry["source_locator_review"], entry["clinical_relevance_review"]
        if source and clinical and (source["reviewer_id"] == clinical["reviewer_id"]
                                    or clinical["reviewer_id"] in developers):
            failures.append("review.requires_independent_clinical_reviewer")
    for tag in COVERAGE_TAGS:
        if sum(tag in c.get("tags", []) for c in cases["cases"]) < coverage:
            failures.append(f"review.coverage_missing:{tag}")
    return sorted(set(failures))


def freeze_benchmark(*, report: dict, cases: dict, chunks: list[dict], bindings: dict,
                     corpus_freeze: dict, ledger: dict, developers: list[str],
                     visible_evaluations: list[dict]) -> dict:
    validate_cases(cases["cases"], chunks, {"development", "validation"})
    validate_report(report, cases, chunks, bindings)
    if not developers or any(not d.strip() for d in developers):
        raise ManualGraphError("benchmark freeze requires developer identities")
    failures = review_failures(cases, corpus_freeze, ledger, developers, 30, 8)
    if not {"development", "validation"}.issubset({c["split"] for c in cases["cases"]}):
        failures.append("evaluation.requires_development_and_validation")
    if report.get("dataset_kind") != "visible":
        failures.append("evaluation.must_be_visible")
    for name in STRATEGIES:
        if report["strategies"].get(name, {}).get("status") != "evaluated":
            failures.append(f"matrix.not_evaluated:{name}")
    if failures:
        raise ManualGraphError("benchmark freeze blocked: " + "; ".join(failures))
    ranked = sorted(STRATEGIES, key=lambda name: (
        -(report["strategies"][name]["by_split"]["validation"]["recall_at_5"] or 0),
        -(report["strategies"][name]["by_split"]["validation"]["abstention_accuracy"] or 0),
        STRATEGIES.index(name)))
    selected = ranked[:2]
    if "graph" in selected:
        selected = ["hybrid", "graph"]  # Paired graph comparison requires the same hybrid seeds.
    registry = sorted(set(content_sha256(e) for e in [cases, *visible_evaluations]))
    return sign({"schema_version": 1, "mode": "retrieval_benchmark_freeze", "code": code_identity(),
                 "bindings": bindings, "visible_evaluation_sha256": content_sha256(cases),
                 "visible_registry_sha256": registry, "visible_report_sha256": report["content_sha256"],
                 "review_ledger_sha256": ledger["content_sha256"], "developer_ids": sorted(set(developers)),
                 "selected_strategies": selected, "selection_policy": "validation_recall_abstention_simplicity_v1",
                 "release_ready": False})


def validate_benchmark_freeze(freeze: dict, bindings: dict) -> None:
    verify(freeze, "retrieval_benchmark_freeze")
    if freeze.get("code") != code_identity() or freeze.get("bindings") != bindings:
        raise ManualGraphError("benchmark freeze is stale; rebuild before sealing a new holdout")
    selected = freeze.get("selected_strategies")
    if not isinstance(selected, list) or not 1 <= len(selected) <= 2 or len(set(selected)) != len(selected) or set(selected) - set(STRATEGIES):
        raise ManualGraphError("invalid frozen strategy shortlist")


def seal_for_benchmark(submission: dict, corpus_freeze: dict, visible: list[dict], freeze: dict) -> dict:
    validate_benchmark_freeze(freeze, freeze["bindings"])
    if sorted(set(content_sha256(e) for e in visible)) != freeze["visible_registry_sha256"]:
        raise ManualGraphError("holdout seal must check the complete frozen visible registry")
    marker = seal_independent_holdout(submission=submission, corpus_freeze=corpus_freeze,
                                     visible_evaluations=visible)
    if submission["independence"]["author_id"] in freeze["developer_ids"]:
        raise ManualGraphError("holdout author must be independent of developers")
    marker["benchmark_freeze_sha256"] = freeze["content_sha256"]
    # Existing sealed marker excludes its timestamp from the integrity hash.
    marker["content_sha256"] = content_sha256({k: v for k, v in marker.items()
                                               if k not in {"created_at_utc", "content_sha256"}})
    return marker


def consume_holdout(*, workspace: Path, submission: dict, marker: dict, freeze: dict,
                    corpus_freeze: dict, ledger: dict, chunks: list[dict], retrievers: dict,
                    bindings: dict) -> tuple[dict, dict]:
    validate_benchmark_freeze(freeze, bindings)
    validate_sealed_independent_holdout(sealed_holdout=marker, submission=submission, corpus_freeze=corpus_freeze)
    if marker.get("benchmark_freeze_sha256") != freeze["content_sha256"]:
        raise ManualGraphError("holdout must be sealed after the exact benchmark freeze")
    validate_cases(submission["cases"], chunks, {"holdout"})
    failures = review_failures(submission, corpus_freeze, ledger, freeze["developer_ids"], 10, 1)
    if submission["independence"]["author_id"] in freeze["developer_ids"]:
        failures.append("holdout.author_is_a_developer")
    if failures:
        raise ManualGraphError("holdout blocked: " + "; ".join(failures))
    selected = {name: retrievers[name] for name in freeze["selected_strategies"] if name in retrievers}
    if set(selected) != set(freeze["selected_strategies"]):
        raise ManualGraphError("frozen strategy is unavailable")
    # Global per-submission receipt prevents copying/resealing a marker for another plan.
    root = local_path(workspace, workspace / "backend/artifacts/nutrition-knowledge-local/holdout-consumption")
    path = root / (content_sha256(submission) + ".json")
    receipt = sign({"schema_version": 1, "mode": "retrieval_holdout_consumption", "state": "consumed_started",
                    "submission_sha256": content_sha256(submission), "marker_sha256": marker["content_sha256"],
                    "freeze_sha256": freeze["content_sha256"], "review_ledger_sha256": ledger["content_sha256"],
                    "started_at_utc": datetime.now(timezone.utc).isoformat()})
    # Different marker paths, metadata, case IDs or another holdout for the same
    # frozen implementation cannot silently turn the final test into tuning.
    write_once(root / ("plan-" + freeze["content_sha256"] + ".json"), receipt)
    write_once(root / ("cases-" + marker["holdout_case_set_sha256"] + ".json"), receipt)
    write_once(path, receipt)
    report = benchmark(cases=submission, chunks=chunks, retrievers=selected, bindings=bindings, holdout=True)
    write_once(root / (report["content_sha256"] + ".report.json"), report)
    receipt = sign({**receipt, "state": "consumed_completed", "report_sha256": report["content_sha256"]})
    write_json(path, receipt)
    return report, receipt


def graph_gate(graph: dict, hybrid: dict) -> list[str]:
    graph_rows = {r["case_id"]: r for r in graph["results"]}
    def recall(row):
        relevant = set(row["relevant_chunk_ids"])
        return len(relevant & {h["chunk_id"] for h in row["hits"]}) / len(relevant) if relevant else 0
    wins = sum("multi_hop" in r["tags"] and recall(graph_rows[r["case_id"]]) > recall(r) for r in hybrid["results"])
    regressions = sum(r["answerability"] == "answerable" and "multi_hop" not in r["tags"]
                      and recall(graph_rows[r["case_id"]]) < recall(r) for r in hybrid["results"])
    latency = graph["metrics"]["latency_p95_ms"]
    failures = []
    if not any(r["answerability"] == "answerable" and "multi_hop" not in r["tags"] for r in hybrid["results"]):
        failures.append("graph.singlehop_comparison_missing")
    if wins < 2:
        failures.append("graph.requires_two_multihop_wins")
    if regressions > 1:
        failures.append("graph.singlehop_regressions")
    if latency > min(1000, 2 * hybrid["metrics"]["latency_p95_ms"]):
        failures.append("graph.latency_exceeds_gate")
    return failures


def release_manifest(*, workspace: Path, visible_report: dict, visible_cases: dict,
                     visible_ledger: dict, corpus_freeze: dict, chunks: list[dict], bindings: dict,
                     freeze: dict | None = None, submission: dict | None = None,
                     holdout_ledger: dict | None = None, holdout_report: dict | None = None) -> dict:
    validate_report(visible_report, visible_cases, chunks, bindings)
    developers = freeze["developer_ids"] if freeze else []
    failures = review_failures(visible_cases, corpus_freeze, visible_ledger, developers, 30, 8)
    for name in STRATEGIES:
        if visible_report["strategies"].get(name, {}).get("status") != "evaluated":
            failures.append(f"matrix.not_evaluated:{name}")
    winners = []
    strategy_failures = {name: hard_gate_failures(entry, "visible")
                         for name, entry in visible_report["strategies"].items()
                         if entry.get("status") == "evaluated"}
    if freeze is None or submission is None or holdout_report is None or holdout_ledger is None:
        failures.append("release.requires_frozen_plan_and_consumed_reviewed_independent_holdout")
    else:
        validate_benchmark_freeze(freeze, bindings)
        if (freeze["visible_report_sha256"] != visible_report["content_sha256"]
                or freeze["review_ledger_sha256"] != visible_ledger["content_sha256"]):
            raise ManualGraphError("release evidence differs from the frozen benchmark")
        validate_cases(submission["cases"], chunks, {"holdout"})
        validate_report(holdout_report, submission, chunks, bindings)
        receipt_path = local_path(workspace, workspace / "backend/artifacts/nutrition-knowledge-local/holdout-consumption" / (content_sha256(submission) + ".json"))
        if not receipt_path.exists():
            raise ManualGraphError("release requires a durable consumption receipt")
        receipt = load_json(receipt_path)
        verify(receipt, "retrieval_holdout_consumption")
        if (receipt.get("state") != "consumed_completed" or receipt.get("freeze_sha256") != freeze["content_sha256"]
                or receipt.get("report_sha256") != holdout_report["content_sha256"]
                or receipt.get("review_ledger_sha256") != holdout_ledger["content_sha256"]
                or receipt.get("submission_sha256") != content_sha256(submission)):
            raise ManualGraphError("holdout receipt does not bind these release artifacts")
        failures += review_failures(submission, corpus_freeze, holdout_ledger, developers, 10, 1)
        if set(holdout_report["strategies"]) != set(freeze["selected_strategies"]):
            raise ManualGraphError("holdout report must contain only the frozen shortlist")
        if holdout_report.get("dataset_kind") != "holdout":
            raise ManualGraphError("release requires an actual holdout report")
        for name in freeze["selected_strategies"]:
            entry = holdout_report["strategies"][name]
            errors = hard_gate_failures(visible_report["strategies"][name], "visible")
            validation = visible_report["strategies"][name]["by_split"]["validation"]
            if validation["recall_at_5"] is None or validation["recall_at_5"] < .90:
                errors.append("validation.recall_at_5_missing_or_below_gate")
            errors += hard_gate_failures(entry, "holdout")
            if name == "hybrid":
                hybrid_groups = visible_report["strategies"]["hybrid"]["results"]
                keyword_groups = visible_report["strategies"]["keyword"]["results"]
                improved = False
                for tag in ("numbers_units", "multi_hop", "edition_conflict"):
                    hybrid_group = summarize([r for r in hybrid_groups if r["split"] == "validation" and tag in r["tags"]])["metrics"]
                    keyword_group = summarize([r for r in keyword_groups if r["split"] == "validation" and tag in r["tags"]])["metrics"]
                    if (hybrid_group["recall_at_5"] or 0) > (keyword_group["recall_at_5"] or 0):
                        improved = True
                if not improved:
                    errors.append("hybrid.no_validation_gain_on_difficult_groups")
            if name == "graph":
                errors += graph_gate(entry, holdout_report["strategies"]["hybrid"])
            strategy_failures[name] = errors
            if not errors:
                winners.append(name)
        if not winners:
            failures.append("release.no_strategy_passes_all_gates")
    winner = min(winners, key=STRATEGIES.index) if winners and not failures else None
    return sign({"schema_version": 1, "mode": "retrieval_release_manifest", "bindings": bindings,
                 "code": code_identity(), "visible_report_sha256": visible_report["content_sha256"],
                 "visible_review_sha256": visible_ledger["content_sha256"],
                 "benchmark_freeze_sha256": freeze["content_sha256"] if freeze else None,
                 "holdout_report_sha256": holdout_report["content_sha256"] if holdout_report else None,
                 "holdout_review_sha256": holdout_ledger["content_sha256"] if holdout_ledger else None,
                 "environment": visible_report["environment"], "selected_strategy": winner,
                 "visible_metrics": {name: {"status": entry["status"], "metrics": entry.get("metrics"),
                     "by_split": entry.get("by_split"), "by_tag": entry.get("by_tag")}
                     for name, entry in visible_report["strategies"].items()},
                 "holdout_metrics": {name: entry.get("metrics") for name, entry in
                                     holdout_report["strategies"].items()} if holdout_report else None,
                 "strategy_gate_failures": strategy_failures, "gate_failures": sorted(set(failures)),
                 "decision": "simplest_strategy_passing_all_gates" if winner else "no_go",
                 "release_ready": winner is not None, "runtime_integration_authorized": False,
                 "scope": "M4_local_retrieval_evidence_only"})
