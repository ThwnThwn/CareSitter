"""All approvals and gold labels here are synthetic test fixtures, never release evidence."""
import copy
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import content_sha256
from nutrition_knowledge_manual.retrieval_artifacts import local_path, sign
from nutrition_knowledge_manual.retrieval_benchmark import (benchmark, hard_gate_failures,
    metrics, STRATEGIES)
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrieval_release import (consume_holdout, freeze_benchmark,
    graph_gate, release_manifest, seal_for_benchmark, validate_report)
from nutrition_knowledge_manual.retrieval_review import empty_retrieval_review, record_retrieval_case_review
from nutrition_knowledge_manual.retrievers import cited_hit


def approve_cases(cases, corpus):
    ledger = empty_retrieval_review(cases=cases, corpus_freeze=corpus)
    for case in cases["cases"]:
        for role in ("data_steward", "dietitian"):
            ledger = record_retrieval_case_review(cases=cases, corpus_freeze=corpus, ledger=ledger,
                case_id=case["case_id"], decision="approved", reviewer_id="synthetic-" + role,
                reviewer_role=role, comment="Synthetic fixture only; no real clinical approval.")
    return ledger


class PerfectFixtureRetriever:
    def __init__(self, chunks, crash=False):
        self.chunks, self.crash = chunks, crash

    def search(self, question, top_k=5, filters=None):
        if self.crash:
            raise ManualGraphError("synthetic inference failure")
        return [] if question.startswith("unanswerable") else [cited_hit(c, 1, "synthetic", {}) for c in self.chunks]


class ReleasePipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name)
        fixture = _Fixture(self.workspace)
        self.corpus = fixture.freeze()
        self.chunks = load_retrieval_chunks(fixture.chunks_path)
        self.visible = fixture.cases()
        self.visible["cases"] = [self.case(i, "development" if i < 15 else "validation", i % 3 == 0) for i in range(30)]
        self.ledger = approve_cases(self.visible, self.corpus)
        self.bindings = {"corpus_freeze_sha256": self.corpus["content_sha256"]}
        self.retrievers = {name: PerfectFixtureRetriever(self.chunks) for name in STRATEGIES}
        self.report = benchmark(cases=self.visible, chunks=self.chunks, retrievers=self.retrievers, bindings=self.bindings)
        self.plan = freeze_benchmark(report=self.report, cases=self.visible, chunks=self.chunks,
            bindings=self.bindings, corpus_freeze=self.corpus, ledger=self.ledger,
            developers=["synthetic-developer"], visible_evaluations=[self.visible])
        self.submission = {"schema_version": 1, "dataset_kind": "independent_holdout_submission",
            "holdout_status": "pending_seal", "corpus": self.visible["corpus"],
            "independence": {"author_id": "synthetic-independent-author", "author_role": "physician",
                "independently_authored": True, "attestation_note": "Synthetic fixture; not actual independence evidence."},
            "cases": [self.case(i + 100, "holdout", i % 3 == 0) for i in range(10)]}
        self.holdout_ledger = approve_cases(self.submission, self.corpus)
        self.marker = seal_for_benchmark(self.submission, self.corpus, [self.visible], self.plan)

    def case(self, number, split, insufficient):
        return {"case_id": f"fixture-{number}", "question": f"{'unanswerable' if insufficient else 'answerable'} fixture {number}",
            "split": split, "answerability": "insufficient_evidence" if insufficient else "answerable",
            "relevant_chunk_ids": [] if insufficient else [c["chunk_id"] for c in self.chunks],
            "tags": ["insufficient_evidence"] if insufficient else ["section_locator", "numbers_units", "multi_hop", "edition_conflict"]}

    def consume(self, retrievers=None):
        return consume_holdout(workspace=self.workspace, submission=self.submission, marker=self.marker,
            freeze=self.plan, corpus_freeze=self.corpus, ledger=self.holdout_ledger, chunks=self.chunks,
            retrievers=retrievers or self.retrievers, bindings=self.bindings)

    def release(self, report=None):
        return release_manifest(workspace=self.workspace, visible_report=self.report,
            visible_cases=self.visible, visible_ledger=self.ledger, corpus_freeze=self.corpus,
            chunks=self.chunks, bindings=self.bindings, freeze=self.plan if report else None,
            submission=self.submission if report else None, holdout_ledger=self.holdout_ledger if report else None,
            holdout_report=report)

    def test_complete_synthetic_pipeline_selects_simple_strategy_but_no_runtime_authorization(self):
        report, receipt = self.consume()
        self.assertEqual("consumed_completed", receipt["state"])
        manifest = self.release(report)
        self.assertTrue(manifest["release_ready"])
        self.assertEqual("keyword", manifest["selected_strategy"])
        self.assertFalse(manifest["runtime_integration_authorized"])

    def test_copying_or_resealing_marker_cannot_reuse_holdout(self):
        self.consume()
        self.marker = seal_for_benchmark(self.submission, self.corpus, [self.visible], self.plan)
        with self.assertRaisesRegex(ManualGraphError, "consumed"):
            self.consume()

    def test_failure_after_consumption_cannot_retry_holdout(self):
        broken = {name: PerfectFixtureRetriever(self.chunks, crash=True) for name in STRATEGIES}
        with self.assertRaisesRegex(ManualGraphError, "inference failure"):
            self.consume(broken)
        with self.assertRaisesRegex(ManualGraphError, "consumed"):
            self.consume()

    def test_missing_review_and_holdout_do_not_release(self):
        manifest = self.release()
        self.assertFalse(manifest["release_ready"])
        self.assertTrue(manifest["gate_failures"])
        self.ledger = empty_retrieval_review(cases=self.visible, corpus_freeze=self.corpus)
        with self.assertRaisesRegex(ManualGraphError, "pending_or_rejected"):
            freeze_benchmark(report=self.report, cases=self.visible, chunks=self.chunks,
                bindings=self.bindings, corpus_freeze=self.corpus, ledger=self.ledger,
                developers=["synthetic-developer"], visible_evaluations=[self.visible])

    def test_plan_changes_and_unbound_marker_are_rejected_before_consumption(self):
        self.plan["code"]["sha256"] = "tampered"
        self.plan = sign(self.plan)
        with self.assertRaisesRegex(ManualGraphError, "stale"):
            self.consume()

    def test_visible_questions_cannot_be_relabelled_with_different_citations(self):
        self.submission["cases"][0]["question"] = self.visible["cases"][1]["question"].upper() + "  "
        with self.assertRaisesRegex(ManualGraphError, "reuses"):
            seal_for_benchmark(self.submission, self.corpus, [self.visible], self.plan)

    def test_forged_metrics_and_citations_are_rejected_even_if_rehashed(self):
        changed = copy.deepcopy(self.report)
        changed["strategies"]["keyword"]["metrics"]["recall_at_5"] = .5
        with self.assertRaisesRegex(ManualGraphError, "metrics"):
            validate_report(sign(changed), self.visible, self.chunks, self.bindings)
        changed = copy.deepcopy(self.report)
        row = next(r for r in changed["strategies"]["keyword"]["results"] if r["hits"])
        row["hits"][0]["source_locator"] = "fabricated"
        with self.assertRaisesRegex(ManualGraphError, "fabricated"):
            validate_report(sign(changed), self.visible, self.chunks, self.bindings)

    def test_holdout_cannot_be_run_as_visible_benchmark(self):
        with self.assertRaisesRegex(ManualGraphError, "holdout"):
            benchmark(cases=self.submission, chunks=self.chunks, retrievers=self.retrievers, bindings=self.bindings)

    def test_metric_is_multi_evidence_recall_not_only_any_hit_and_absence_is_null(self):
        row = {"answerability": "answerable", "relevant_chunk_ids": ["a", "b"],
               "hits": [{"chunk_id": "a"}], "latency_ms": 1}
        result = metrics([row])
        self.assertEqual(.5, result["recall_at_5"])
        self.assertIsNone(result["abstention_accuracy"])

    def test_edition_conflict_group_uses_abstention_when_no_answer_is_possible(self):
        entry = copy.deepcopy(self.report["strategies"]["keyword"])
        entry["by_tag"]["edition_conflict"] = {
            "case_count": 8, "answerable_case_count": 0, "insufficient_evidence_count": 8,
            "recall_at_5": None, "abstention_accuracy": 1.0,
        }
        self.assertEqual([], hard_gate_failures(entry, "visible"))
        entry["by_tag"]["edition_conflict"]["abstention_accuracy"] = .75
        self.assertIn("visible.risk_group_abstention_below_gate:edition_conflict",
                      hard_gate_failures(entry, "visible"))
        entry["by_tag"]["edition_conflict"].update(
            answerable_case_count=1, recall_at_5=.5, abstention_accuracy=1.0)
        self.assertIn("visible.risk_group_below_gate:edition_conflict",
                      hard_gate_failures(entry, "visible"))

    def test_artifact_paths_cannot_escape_local_boundary(self):
        with self.assertRaises(ManualGraphError):
            local_path(self.workspace, self.workspace / "../outside.json")

    def test_graph_requires_real_paired_improvement_and_latency_budget(self):
        baseline_rows = [{"case_id": str(i), "answerability": "answerable",
            "tags": ["multi_hop"] if i < 2 else [], "relevant_chunk_ids": ["a", "b"],
            "hits": [{"chunk_id": "a"}]} for i in range(3)]
        graph_rows = copy.deepcopy(baseline_rows)
        for row in graph_rows[:2]:
            row["hits"].append({"chunk_id": "b"})
        baseline = {"results": baseline_rows, "metrics": {"latency_p95_ms": 100}}
        graph = {"results": graph_rows, "metrics": {"latency_p95_ms": 150}}
        self.assertEqual([], graph_gate(graph, baseline))
        graph["metrics"]["latency_p95_ms"] = 250
        self.assertIn("graph.latency_exceeds_gate", graph_gate(graph, baseline))
        graph["results"] = copy.deepcopy(baseline_rows)
        self.assertIn("graph.requires_two_multihop_wins", graph_gate(graph, baseline))

    def test_new_holdout_cannot_be_used_for_second_attempt_on_same_plan(self):
        self.consume()
        self.submission["cases"][0]["question"] += " new"
        self.holdout_ledger = approve_cases(self.submission, self.corpus)
        self.marker = seal_for_benchmark(self.submission, self.corpus, [self.visible], self.plan)
        with self.assertRaisesRegex(ManualGraphError, "consumed"):
            self.consume()


if __name__ == "__main__":
    unittest.main()
