"""Synthetic-only tests for local heading checks and scoped human worksheets."""
import copy
import csv
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch
import unittest

import test_graph_regressions
from test_reviewed_graph_retrieval import approve_graph
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.graph_source_review import (
    build_assessment, check_scope, main, pdf_outline,
)
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.retrieval_graph import (
    build_graph_candidate, empty_graph_review, materialize_graph,
)
from nutrition_knowledge_manual.review_batch import build_graph_review_export, plan_review_import

SCRIPT = Path(__file__).resolve().parents[5] / "scripts/nutrition-review-sheet.py"
spec = importlib.util.spec_from_file_location("r2_review_sheet", SCRIPT)
sheet_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sheet_tool)


class GraphSourceReviewTests(unittest.TestCase):
    def setUp(self):
        test_graph_regressions.GraphRegressionTests.setUp(self)
        self.root = Path(self.temp.name)
        self.chunks[0]["headings"] = ["CHƯƠNG TỔNG HỢP A", "II. CAN THIỆP"]
        self.chunks[1]["headings"] = []
        self.candidate = build_graph_candidate(self.chunks, self.freeze)
        self.ledger = empty_graph_review(self.candidate, self.freeze)
        chunks_path = self.root / "updated.jsonl"
        chunks_path.write_text("".join(json.dumps(c) + "\n" for c in self.chunks), encoding="utf-8")
        self.packet = build_graph_review_export(candidate=self.candidate,
            corpus_freeze=self.freeze, ledger=self.ledger, chunks_path=chunks_path)
        self.outline = {
            1: {"explicit": [("CHƯƠNG TỔNG HỢP A",), ("CHƯƠNG TỔNG HỢP A", "II. CAN THIỆP")],
                "active": {("CHƯƠNG TỔNG HỢP A",), ("CHƯƠNG TỔNG HỢP A", "II. CAN THIỆP")},
                "has_headings": True},
            2: {"explicit": [], "active": {("CHƯƠNG TỔNG HỢP A",),
                ("CHƯƠNG TỔNG HỢP A", "II. CAN THIỆP")}, "has_headings": False},
        }
        self.assessment = build_assessment(self.candidate, self.packet, self.freeze,
                                          self.outline, self.freeze["source_sha256"])
        self.sheet = self.root / "sheet.csv"
        self.chapters = ["CHƯƠNG TỔNG HỢP A"]

    def export(self):
        return sheet_tool.export_sheet(self.packet, self.candidate, self.sheet,
            "data_steward", self.assessment, self.chapters)

    def rows(self):
        with self.sheet.open(encoding="utf-8-sig", newline="") as stream:
            return list(csv.DictReader(stream))

    def save(self, rows):
        with self.sheet.open("w", encoding="utf-8-sig", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)

    def build(self, reviewer="synthetic-steward", role="data_steward"):
        return sheet_tool.build_batch(self.packet, self.candidate, self.sheet,
            reviewer, role, self.root / "batch.json", self.assessment, self.chapters)

    def test_scope_basis_heading_ancestor_continuation_and_boundary(self):
        for basis, path, page in (("heading", ["CHƯƠNG TỔNG HỢP A", "II. CAN THIỆP"], 1),
                                 ("outline_ancestor", ["CHƯƠNG TỔNG HỢP A"], 1),
                                 ("continuation", ["CHƯƠNG TỔNG HỢP A"], 2)):
            with self.subTest(basis=basis):
                self.assertEqual("match", check_scope(path, basis, [page], [1], self.outline)[0])
        changed = copy.deepcopy(self.outline)
        changed[2]["active"] = {("CHƯƠNG KHÁC",)}
        self.assertEqual("mismatch", check_scope(self.chapters, "continuation", [2], [1], changed)[0])
        self.assertEqual("unknown", check_scope(self.chapters, "heading", [99], [1], changed)[0])
        self.assertEqual("unknown", check_scope(["CHƯƠNG KHÔNG TRÍCH ĐƯỢC"], "heading",
                                               [1], [1], changed)[0])

    def test_pdf_outline_reads_pages_without_exporting_paragraphs(self):
        class Page:
            def extract_text(self, **kwargs):
                return "CHƯƠNG TỔNG HỢP A\n\nSynthetic private prose never exported."
            def close(self):
                pass
        with patch("pdfplumber.open") as opened:
            opened.return_value.__enter__.return_value.pages = [Page()]
            result = pdf_outline(self.root / "synthetic.pdf")
        self.assertIn(("CHƯƠNG TỔNG HỢP A",), result[1]["active"])
        self.assertNotIn("private prose", str(result))

    def test_blank_pdf_page_breaks_continuation(self):
        class Page:
            def __init__(self, text):
                self.text = text
            def extract_text(self, **kwargs):
                return self.text
            def close(self):
                pass
        with patch("pdfplumber.open") as opened:
            opened.return_value.__enter__.return_value.pages = [
                Page("CHƯƠNG TỔNG HỢP A"), Page(""), Page("Synthetic prose only.")]
            outline = pdf_outline(self.root / "synthetic.pdf")
        self.assertEqual(set(), outline[2]["active"])
        self.assertEqual("unknown", check_scope(self.chapters, "continuation", [3], [1], outline)[0])

    def test_hash_is_checked_before_pdf_extraction(self):
        pdf = self.root / "synthetic.pdf"
        pdf.write_bytes(b"synthetic not a PDF")
        manifest = self.root / "manifest.json"
        manifest.write_text(json.dumps({"sources": [{"source_id": "fixture", "path": pdf.name,
            "rights_status": "synthetic", "allowed_uses": ["local_index", "local_query", "internal_citation"],
            "sha256": "0" * 64, "byte_size": pdf.stat().st_size}]}), encoding="utf-8")
        with patch("nutrition_knowledge_manual.graph_source_review.pdf_outline") as extract:
            with self.assertRaisesRegex(ManualGraphError, "hash mismatch"):
                main(["--workspace", str(self.root), "--manifest", str(manifest),
                      "--source-id", "fixture", "--packet", "unused", "--candidate", "unused",
                      "--corpus-freeze", "unused", "--output", "unused"])
            extract.assert_not_called()

    def test_assessment_has_no_decisions_or_paragraphs_and_both_edge_directions(self):
        self.assertFalse(self.assessment["release_ready"])
        self.assertNotIn('"decision"', json.dumps(self.assessment))
        matches = {row["type"] for row in self.candidate["edges"]
                   if self.assessment["records"][row["id"]]["auto_check"] == "match"}
        self.assertEqual({"MENTIONS", "SUPPORTED_BY"}, matches)
        for bad in ("packet", "pdf", "record"):
            packet = copy.deepcopy(self.packet)
            pdf_hash = self.freeze["source_sha256"]
            if bad == "packet":
                packet["target_content_sha256"] = "f" * 64
            elif bad == "record":
                packet["records"][0]["record_sha256"] = "f" * 64
            else:
                pdf_hash = "f" * 64
            with self.subTest(bad=bad), self.assertRaises(ManualGraphError):
                build_assessment(self.candidate, sign(packet), self.freeze, self.outline, pdf_hash)

    def test_scoped_sheet_includes_dependencies_and_leaves_decisions_blank(self):
        count = self.export()
        rows = self.rows()
        ids = {row["record_id"] for row in rows}
        self.assertEqual(count, self.assessment["chapter_record_counts"][self.chapters[0]])
        self.assertTrue(all(not r["decision"] and not r["comment"] and not r["reviewer_id"] for r in rows))
        for edge in self.candidate["edges"]:
            if edge["id"] in ids:
                self.assertTrue({edge["from"], edge["to"], *edge["scope_evidence_chunk_ids"]} <= ids)
        with self.assertRaises(ManualGraphError):
            self.export()

    def test_edited_immutable_columns_packet_hash_role_and_advice_are_rejected(self):
        self.export()
        original = self.rows()
        immutable = [key for key in original[0] if key not in {"decision", "comment", "reviewer_id"}]
        for field in immutable:
            changed = copy.deepcopy(original)
            changed[0][field] += "edited"
            self.save(changed)
            with self.subTest(field=field), self.assertRaises(ManualGraphError):
                self.build()

    def test_missing_comment_reviewer_wrong_role_and_malformed_rows_fail(self):
        self.export()
        original = self.rows()
        for update in ({"decision": "approved"},
                       {"decision": "approved", "comment": "Synthetic only"},
                       {"decision": "approved", "comment": "Synthetic only", "reviewer_id": "other"}):
            rows = copy.deepcopy(original)
            rows[0].update(update)
            self.save(rows)
            with self.subTest(update=update), self.assertRaises(ManualGraphError):
                self.build()
        self.save(original)
        with self.assertRaises(ManualGraphError):
            self.build(reviewer="")
        with self.assertRaises(ManualGraphError):
            self.build(role="developer")
        for rows in (original[:-1], original[1:] + [original[1]]):
            self.save(rows)
            with self.assertRaises(ManualGraphError):
                self.build()

    def test_partial_decision_batch_uses_existing_importer_and_pending_stays_out(self):
        self.export()
        rows = self.rows()
        rows[0].update(decision="approved", comment="Synthetic test only", reviewer_id="synthetic-steward")
        self.save(rows)
        self.assertEqual(1, self.build())
        batch_path = self.root / "batch.json"
        batch = json.loads(batch_path.read_text(encoding="utf-8"))
        plan = plan_review_import(target=self.candidate, corpus_freeze=self.freeze,
            ledger=self.ledger, batch=batch, batch_path=batch_path)
        self.assertTrue(plan["can_apply"])
        self.assertEqual([], materialize_graph(self.candidate, self.freeze, self.ledger)["nodes"])
        approved = approve_graph(self.candidate, self.freeze)
        for kind in ("chunk", "topic", "MENTIONS", "SUPPORTED_BY"):
            rid = next(r["id"] for r in self.candidate["nodes"] + self.candidate["edges"] if r["type"] == kind)
            for slot in ("source_review", "clinical_review"):
                pending = copy.deepcopy(approved)
                pending["records"][rid][slot] = None
                graph = materialize_graph(self.candidate, self.freeze, sign(pending))
                with self.subTest(kind=kind, slot=slot):
                    self.assertNotIn(rid, {r["id"] for r in graph["nodes"] + graph["edges"]})
                    self.assertFalse(any(rid in (e["from"], e["to"]) or
                        rid in e.get("scope_evidence_chunk_ids", []) for e in graph["edges"]))

    def test_unknown_chapter_and_stale_assessment_rejected(self):
        with self.assertRaises(ManualGraphError):
            sheet_tool.export_sheet(self.packet, self.candidate, self.sheet,
                                    "data_steward", self.assessment, ["unknown"])
        stale = sign({**self.assessment, "packet_sha256": "f" * 64})
        with self.assertRaises(ManualGraphError):
            sheet_tool.export_sheet(self.packet, self.candidate, self.sheet,
                                    "data_steward", stale, self.chapters)

    def test_legacy_case_sheet_still_checks_packet_content(self):
        packet = sign({**self.packet, "target_kind": "case", "records": [
            {"case_id": "synthetic-case", "record_sha256": "a" * 64,
             "question": "Synthetic question?", "candidate_citations": []}],
            "decision_batch_template": {**self.packet["decision_batch_template"],
                "target_kind": "case", "decisions": [
                    {"case_id": "synthetic-case", "record_sha256": "a" * 64}]}})
        sheet_tool.export_sheet(packet, None, self.sheet, "data_steward")
        rows = self.rows()
        rows[0].update(decision="approved", comment="Synthetic only")
        self.save(rows)
        self.assertEqual(1, sheet_tool.build_batch(packet, None, self.sheet,
            "synthetic-steward", "data_steward", self.root / "legacy.json"))
        rows[0]["question_or_label"] = "Edited question"
        self.save(rows)
        with self.assertRaises(ManualGraphError):
            sheet_tool.build_batch(packet, None, self.sheet,
                "synthetic-steward", "data_steward", self.root / "forged.json")


if __name__ == "__main__":
    unittest.main()
