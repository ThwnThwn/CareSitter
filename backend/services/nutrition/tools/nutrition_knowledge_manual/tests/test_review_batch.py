from __future__ import annotations

import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from test_retrieval_review import _Fixture
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.cli import main
from nutrition_knowledge_manual.jsonio import content_sha256, load_json, write_json
from nutrition_knowledge_manual.retrieval_artifacts import sign, write_once_atomic
from nutrition_knowledge_manual.retrieval_graph import build_graph_candidate, empty_graph_review
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrieval_review import empty_retrieval_review
from nutrition_knowledge_manual.review_batch import (
    BATCH_MODE,
    apply_review_import,
    build_case_review_export,
    build_graph_review_export,
    plan_review_import,
)


class ReviewBatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fixture = _Fixture(self.root)
        self.freeze = self.fixture.freeze()
        self.cases = self.fixture.cases()
        self.case_ledger = empty_retrieval_review(cases=self.cases, corpus_freeze=self.freeze)
        self.candidate = build_graph_candidate(load_retrieval_chunks(self.fixture.chunks_path), self.freeze)
        self.graph_ledger = empty_graph_review(self.candidate, self.freeze)
        self.batch_path = self.root / "completed-review.json"

    def _batch(self, *, kind="case", role="data_steward", decisions=None, ledger=None):
        target = self.cases if kind == "case" else self.candidate
        ledger = ledger or (self.case_ledger if kind == "case" else self.graph_ledger)
        id_key = "case_id" if kind == "case" else "record_id"
        record_id = (self.cases["cases"][0]["case_id"] if kind == "case"
                     else sorted(self.graph_ledger["records"])[0])
        record_hash = (content_sha256(self.cases["cases"][0]) if kind == "case"
                       else self.graph_ledger["records"][record_id]["record_sha256"])
        value = sign({
            "schema_version": 1, "mode": BATCH_MODE, "target_kind": kind,
            "corpus_freeze_sha256": self.freeze["content_sha256"],
            "target_content_sha256": (ledger["evaluation_content_sha256"] if kind == "case"
                                      else target["content_sha256"]),
            "ledger_content_sha256": ledger["content_sha256"],
            "reviewer_id": "fixture-reviewer", "reviewer_role": role,
            "decision_source": {"type": "completed_review_file", "reference": "fixture-only",
                                "attested": True},
            "decisions": decisions or [{id_key: record_id, "record_sha256": record_hash,
                                         "decision": "approved", "comment": "Fixture decision."}],
        })
        write_json(self.batch_path, value)
        return value

    def _plan(self, batch, *, kind="case", ledger=None):
        return plan_review_import(
            target=self.cases if kind == "case" else self.candidate,
            corpus_freeze=self.freeze,
            ledger=ledger or (self.case_ledger if kind == "case" else self.graph_ledger),
            batch=batch,
            batch_path=self.batch_path,
        )

    def test_case_export_keeps_owner_approval_separate(self):
        decisions = [{"case_id": row["case_id"], "case_content_sha256": content_sha256(row),
                      "owner_decision": "approved"} for row in self.cases["cases"]]
        approval = sign({"schema_version": 1, "mode": "product_owner_visible_case_approval",
                         "case_set_sha256": self.case_ledger["evaluation_content_sha256"],
                         "decisions": decisions})
        result = build_case_review_export(cases=self.cases, corpus_freeze=self.freeze,
                                          ledger=self.case_ledger, chunks_path=self.fixture.chunks_path,
                                          owner_approval=approval)
        self.assertEqual("approved", result["records"][0]["owner_approval"])
        self.assertIsNone(result["records"][0]["source_locator_review"])
        self.assertIn("pdf_page", result["records"][0]["candidate_citations"][0])
        self.assertEqual("retrieval_review_decision_batch", result["decision_batch_template"]["mode"])
        self.assertIsNone(result["decision_batch_template"]["decisions"][0]["decision"])

    def test_graph_export_includes_scope_heading_and_anchor_pages(self):
        result = build_graph_review_export(candidate=self.candidate, corpus_freeze=self.freeze,
                                           ledger=self.graph_ledger, chunks_path=self.fixture.chunks_path)
        self.assertEqual(len(self.graph_ledger["records"]), len(result["records"]))
        self.assertTrue(all("scope_basis" in row and "heading" in row for row in result["records"]))
        self.assertTrue(any(row["evidence"] for row in result["records"]))

    def test_dry_run_reports_stale_missing_duplicate_conflict_and_wrong_role(self):
        first = self.cases["cases"][0]
        good = {"case_id": first["case_id"], "record_sha256": content_sha256(first),
                "decision": "approved", "comment": "Fixture decision."}
        cases = (
            ([{**good, "record_sha256": "0" * 64}], "stale_hash"),
            ([{**good, "case_id": "removed"}], "missing"),
            ([good, good], "duplicate"),
            ([good, {**good, "decision": "rejected"}], "conflict"),
        )
        for decisions, category in cases:
            batch = self._batch(decisions=decisions)
            self.assertTrue(self._plan(batch)["outcomes"][category])
        batch = self._batch(role="product_owner")
        self.assertTrue(self._plan(batch)["outcomes"]["wrong_role"])

    def test_apply_is_hash_bound_idempotent_and_adds_receipt(self):
        batch = self._batch()
        plan = self._plan(batch)
        applied = apply_review_import(target=self.cases, corpus_freeze=self.freeze,
                                      ledger=self.case_ledger, batch=batch, batch_path=self.batch_path,
                                      plan=plan, imported_at_utc="2026-10-27T08:00:00+07:00")
        entry = applied["decisions"][0]
        self.assertEqual("approved", entry["source_locator_review"]["decision"])
        self.assertEqual(1, len(applied["import_receipts"]))
        again_plan = self._plan(batch, ledger=applied)
        self.assertEqual([entry["case_id"]], again_plan["outcomes"]["unchanged"])
        repeated = apply_review_import(target=self.cases, corpus_freeze=self.freeze,
            ledger=applied, batch=batch, batch_path=self.batch_path, plan=again_plan,
            imported_at_utc="2026-10-27T08:05:00+07:00")
        self.assertEqual(applied, repeated)

    def test_apply_rejects_batch_changed_after_dry_run(self):
        batch = self._batch()
        plan = self._plan(batch)
        changed = copy.deepcopy(batch)
        changed["decisions"][0]["comment"] = "Changed after dry-run."
        changed = sign(changed)
        write_json(self.batch_path, changed)
        with self.assertRaisesRegex(ManualGraphError, "changed after dry-run"):
            apply_review_import(target=self.cases, corpus_freeze=self.freeze,
                                ledger=self.case_ledger, batch=changed, batch_path=self.batch_path,
                                plan=plan)

    def test_same_reviewer_cannot_fill_both_graph_roles(self):
        source_batch = self._batch(kind="graph", role="data_steward")
        source_plan = self._plan(source_batch, kind="graph")
        applied = apply_review_import(target=self.candidate, corpus_freeze=self.freeze,
                                      ledger=self.graph_ledger, batch=source_batch,
                                      batch_path=self.batch_path, plan=source_plan,
                                      imported_at_utc="2026-10-27T08:00:00+07:00")
        clinical_batch = self._batch(kind="graph", role="dietitian", ledger=applied)
        plan = self._plan(clinical_batch, kind="graph", ledger=applied)
        self.assertTrue(plan["outcomes"]["wrong_role"])

    def test_graph_heading_rejection_is_imported_by_record_hash(self):
        topic_id = next(row["id"] for row in self.candidate["nodes"] if row["type"] == "topic")
        row_hash = self.graph_ledger["records"][topic_id]["record_sha256"]
        batch = self._batch(kind="graph", decisions=[{
            "record_id": topic_id, "record_sha256": row_hash, "decision": "rejected",
            "comment": "Fixture heading anchor is invalid.",
        }])
        plan = self._plan(batch, kind="graph")
        applied = apply_review_import(target=self.candidate, corpus_freeze=self.freeze,
                                      ledger=self.graph_ledger, batch=batch,
                                      batch_path=self.batch_path, plan=plan,
                                      imported_at_utc="2026-10-27T08:00:00+07:00")
        self.assertEqual("rejected", applied["records"][topic_id]["source_review"]["decision"])

    def test_apply_requires_attested_decision_source(self):
        batch = self._batch()
        batch["decision_source"]["attested"] = False
        batch = sign(batch)
        write_json(self.batch_path, batch)
        with self.assertRaisesRegex(ManualGraphError, "decision source"):
            self._plan(batch)

    def test_apply_requires_timezone_on_import_timestamp(self):
        batch = self._batch()
        plan = self._plan(batch)
        with self.assertRaisesRegex(ManualGraphError, "include a timezone"):
            apply_review_import(target=self.cases, corpus_freeze=self.freeze,
                ledger=self.case_ledger, batch=batch, batch_path=self.batch_path,
                plan=plan, imported_at_utc="2026-10-27T08:00:00")

    def test_cli_dry_run_then_apply_writes_a_new_ledger_revision(self):
        batch = self._batch()
        cases_path, freeze_path, ledger_path = (self.root / name for name in
                                                ("cases.json", "freeze.json", "ledger.json"))
        for path, value in ((cases_path, self.cases), (freeze_path, self.freeze),
                            (ledger_path, self.case_ledger)):
            write_json(path, value)
        artifact_dir = self.root / "backend/artifacts/nutrition-knowledge-local/evaluation"
        plan_path, output_path = artifact_dir / "plan.json", artifact_dir / "ledger.v2.json"
        common = ["--workspace", str(self.root), "--target-kind", "case", "--target", str(cases_path),
                  "--corpus-freeze", str(freeze_path), "--ledger", str(ledger_path),
                  "--batch", str(self.batch_path)]
        self.assertEqual(0, main([common[0], common[1], "plan-retrieval-review-import",
                                  *common[2:], "--output", str(plan_path)]))
        self.assertEqual(0, main([common[0], common[1], "apply-retrieval-review-import",
                                  *common[2:], "--plan", str(plan_path), "--output", str(output_path)]))
        self.assertEqual("approved", load_json(output_path)["decisions"][0]["source_locator_review"]["decision"])

    def test_atomic_writer_does_not_publish_partial_output_when_publish_fails(self):
        output = self.root / "ledger.v2.json"
        with patch("nutrition_knowledge_manual.retrieval_artifacts.os.link", side_effect=OSError("fixture crash")):
            with self.assertRaisesRegex(OSError, "fixture crash"):
                write_once_atomic(output, {"value": 1})
        self.assertFalse(output.exists())
        self.assertEqual([], list(self.root.glob(".ledger.v2.json.*.tmp")))


if __name__ == "__main__":
    unittest.main()
