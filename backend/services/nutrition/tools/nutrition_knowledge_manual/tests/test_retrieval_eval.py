from __future__ import annotations

import copy
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "tests"))

from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.retrieval_eval import run_retrieval_eval
from test_retrieval_review import _Fixture


class RetrievalEvaluationTests(unittest.TestCase):
    def test_keyword_baseline_reports_metrics_but_never_declares_release_ready(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()

            report = run_retrieval_eval(
                cases=cases,
                chunks_path=fixture.chunks_path,
                corpus_freeze=freeze,
                top_k=5,
                minimum_cases=2,
            )

            self.assertEqual(1.0, report["metrics"]["recall_at_k"])
            self.assertEqual(1.0, report["metrics"]["citation_integrity"])
            self.assertFalse(report["release_ready"])
            self.assertIn(
                "release.requires_review_ledger_sealed_holdout_paired_benchmark_and_manifest",
                report["gate_failures"],
            )
            self.assertFalse(report["generation_enabled"])
            self.assertIsNone(report["metrics"]["abstention_accuracy"])

    def test_embedded_review_claims_cannot_bypass_external_release_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()
            for item in cases["cases"]:
                item["review_status"] = "reviewed"
                item["review"] = {
                    "reviewer_id": "dietitian-fixture",
                    "reviewer_role": "dietitian",
                    "comment": "Synthetic claim only",
                }

            report = run_retrieval_eval(
                cases=cases,
                chunks_path=fixture.chunks_path,
                corpus_freeze=freeze,
                top_k=5,
                minimum_cases=2,
            )

            self.assertFalse(report["release_ready"])
            self.assertFalse(report["validation"]["review_complete"])
            self.assertFalse(report["validation"]["gold_ready"])
            self.assertEqual(2, report["validation"]["embedded_review_claim_count"])

    def test_insufficient_evidence_case_requires_no_citations_and_scores_abstention(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()
            cases["cases"].append({
                "case_id": "case-insufficient",
                "question": "qzxwvu no matching evidence token",
                "split": "validation",
                "answerability": "insufficient_evidence",
                "relevant_chunk_ids": [],
                "review_status": "candidate",
            })

            report = run_retrieval_eval(
                cases=cases,
                chunks_path=fixture.chunks_path,
                corpus_freeze=freeze,
                top_k=5,
                minimum_cases=3,
            )

            self.assertEqual(1, report["metrics"]["insufficient_evidence_count"])
            self.assertEqual(1.0, report["metrics"]["abstention_accuracy"])
            result = next(item for item in report["results"] if item["case_id"] == "case-insufficient")
            self.assertTrue(result["abstained"])

            invalid = copy.deepcopy(cases)
            invalid["cases"][-1]["relevant_chunk_ids"] = ["eligible-a"]
            with self.assertRaisesRegex(ManualGraphError, "must not declare citations"):
                run_retrieval_eval(
                    cases=invalid,
                    chunks_path=fixture.chunks_path,
                    corpus_freeze=freeze,
                    top_k=5,
                    minimum_cases=3,
                )

    def test_eval_rejects_a_different_corpus_revision(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()
            cases["corpus"]["chunks_sha256"] = "0" * 64

            with self.assertRaisesRegex(ManualGraphError, "different chunk artifact"):
                run_retrieval_eval(
                    cases=cases,
                    chunks_path=fixture.chunks_path,
                    corpus_freeze=freeze,
                    top_k=5,
                    minimum_cases=2,
                )

    def test_eval_rejects_manual_review_chunks_as_gold_citations(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()
            cases["cases"][0]["relevant_chunk_ids"] = ["manual-c"]

            with self.assertRaisesRegex(ManualGraphError, "unknown or ineligible"):
                run_retrieval_eval(
                    cases=cases,
                    chunks_path=fixture.chunks_path,
                    corpus_freeze=freeze,
                    top_k=5,
                    minimum_cases=2,
                )


if __name__ == "__main__":
    unittest.main()
