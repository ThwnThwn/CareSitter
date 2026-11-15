"""Graph topology and ranking regressions; all review decisions are synthetic."""
import json
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from test_reviewed_graph_retrieval import approve_graph
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.graph_retriever import GraphRetriever
from nutrition_knowledge_manual.graph_diagnostics import inspect_graph
from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.retrieval_graph import (build_graph_candidate, materialize_graph,
                                                       record_graph_review, validate_candidate)
from nutrition_knowledge_manual.retrievers import cited_hit


class RankedSeeds:
    def __init__(self, chunks):
        self.chunks = chunks

    def search(self, question, top_k=5, filters=None):
        return [cited_hit(chunk, 1 / rank, "synthetic", {})
                for rank, chunk in enumerate(self.chunks[:top_k], 1)]


class GraphRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        fixture = _Fixture(Path(self.temp.name))
        self.chunks = [fixture._chunk(f"fixture-{i}", f"Synthetic text {i}.", True,
                                     "ready_for_retrieval_eval") for i in range(7)]
        for page, chunk in enumerate(self.chunks, 1):
            chunk.update(pdf_page=page, printed_page=str(page), source_locator=f"pdf-page:{page}",
                         headings=[f"CHƯƠNG BỆNH {page}"])
        fixture.chunks_path.write_text("".join(json.dumps(c, ensure_ascii=False) + "\n"
                                              for c in self.chunks), encoding="utf-8")
        report = json.loads(fixture.report_path.read_text(encoding="utf-8"))
        report.update(output_sha256=file_sha256(fixture.chunks_path), chunk_count=7,
                      index_eligible_count=7, review_status_counts={"ready_for_retrieval_eval": 7})
        report.pop("content_sha256")
        report["content_sha256"] = content_sha256(report)
        fixture.report_path.write_text(json.dumps(report), encoding="utf-8")
        self.freeze = fixture.freeze()

    def retriever(self, seeds, **kwargs):
        candidate = build_graph_candidate(self.chunks, self.freeze)
        ledger = approve_graph(candidate, self.freeze)
        graph = materialize_graph(candidate, self.freeze, ledger)
        return GraphRetriever(RankedSeeds(seeds), self.chunks, self.freeze,
                              candidate, ledger, graph, **kwargs)

    def test_sibling_subsections_share_the_explicit_parent_scope(self):
        self.chunks[0]["headings"] = ["CHƯƠNG BỆNH A", "II. CAN THIỆP", "2.1. Năng lượng"]
        self.chunks[1]["headings"] = ["2.2. Protein"]
        candidate = build_graph_candidate(self.chunks, self.freeze)
        parent = next(n for n in candidate["nodes"] if n.get("label") == "CHƯƠNG BỆNH A > II. CAN THIỆP")
        self.assertEqual({"fixture-0", "fixture-1"}, set(parent["evidence_chunk_ids"]))

    def test_page_without_heading_continues_the_previous_section(self):
        self.chunks[0]["headings"] = ["CHƯƠNG BỆNH A", "II. CAN THIỆP"]
        self.chunks[1]["headings"] = []
        candidate = build_graph_candidate(self.chunks, self.freeze)
        parent = next(n for n in candidate["nodes"] if n.get("label") == "CHƯƠNG BỆNH A > II. CAN THIỆP")
        self.assertEqual({"fixture-0", "fixture-1"}, set(parent["evidence_chunk_ids"]))

    def test_graph_support_promotes_a_seed_outside_top_five(self):
        for index in (0, 1, 5):
            self.chunks[index]["headings"] = ["CHƯƠNG BẰNG CHỨNG TỔNG HỢP"]
        retriever = self.retriever(self.chunks[:6])
        hits = retriever.search("synthetic", 5)
        self.assertIn("fixture-5", [h["chunk_id"] for h in hits])
        promoted = next(h for h in hits if h["chunk_id"] == "fixture-5")
        self.assertEqual(2, len(promoted["provenance"]["edge_path"]))

    def test_graph_support_promotes_a_chunk_absent_from_seeds(self):
        for index in (0, 1, 6):
            self.chunks[index]["headings"] = ["CHƯƠNG BẰNG CHỨNG TỔNG HỢP"]
        hits = self.retriever(self.chunks[:5]).search("synthetic", 5)
        self.assertIn("fixture-6", [h["chunk_id"] for h in hits])

    def test_context_does_not_cross_gaps_new_chapters_or_reference_sections(self):
        self.chunks[0]["headings"] = ["CHƯƠNG BỆNH A", "II. CAN THIỆP"]
        for boundary in ("gap", "chapter", "reference", "menu", "unknown"):
            with self.subTest(boundary=boundary):
                self.chunks[1].update(pdf_page=2, headings=[])
                self.chunks[2].update(pdf_page=3, headings=[])
                if boundary == "gap":
                    self.chunks[1]["pdf_page"] = 10
                else:
                    self.chunks[1]["headings"] = {
                        "chapter": ["CHƯƠNG BỆNH B"], "reference": ["TÀI LIỆU THAM KHẢO"],
                        "menu": ["THỰC ĐƠN THAM KHẢO"], "unknown": ["A B C D"],
                    }[boundary]
                candidate = build_graph_candidate(self.chunks, self.freeze)
                old_parent = next(n for n in candidate["nodes"]
                                  if n.get("label") == "CHƯƠNG BỆNH A > II. CAN THIỆP")
                self.assertEqual(["fixture-0"], old_parent["evidence_chunk_ids"])

    def test_continuation_evidence_includes_the_original_heading_page(self):
        self.chunks[0]["headings"] = ["CHƯƠNG BỆNH A", "II. CAN THIỆP"]
        self.chunks[1]["headings"] = []
        candidate = build_graph_candidate(self.chunks, self.freeze)
        edge = next(e for e in candidate["edges"] if e["from"] == "fixture-1")
        self.assertEqual("continuation", edge["scope_basis"])
        self.assertEqual(["fixture-0", "fixture-1"], edge["scope_evidence_chunk_ids"])
        edge["scope_evidence_chunk_ids"] = ["fixture-1"]
        with self.assertRaisesRegex(ManualGraphError, "heading evidence"):
            validate_candidate(sign(candidate), self.freeze)

    def test_rejected_heading_anchor_blocks_dependent_continuation_edges(self):
        self.chunks[0]["headings"] = ["CHƯƠNG BỆNH A", "II. CAN THIỆP"]
        self.chunks[1]["headings"] = []
        candidate = build_graph_candidate(self.chunks, self.freeze)
        ledger = approve_graph(candidate, self.freeze)
        ledger = record_graph_review(candidate, self.freeze, ledger, "fixture-0", "rejected",
                                     "synthetic-data-steward", "data_steward", "Synthetic invalid heading page")
        graph = materialize_graph(candidate, self.freeze, ledger)
        self.assertFalse(any("fixture-1" in (e["from"], e["to"]) for e in graph["edges"]))

    def test_self_cycles_do_not_boost_isolated_seeds(self):
        hits = self.retriever(self.chunks[:5]).search("synthetic", 5)
        self.assertEqual([c["chunk_id"] for c in self.chunks[:5]], [h["chunk_id"] for h in hits])
        for hit in hits:
            self.assertEqual([], hit["provenance"]["edge_path"])
            self.assertEqual([], hit["provenance"]["support_paths"])

    def test_duplicate_outline_routes_count_at_most_once_per_seed(self):
        for index in (0, 1, 5):
            self.chunks[index]["headings"] = ["CHƯƠNG BẰNG CHỨNG", "II. CAN THIỆP", "2.1. Năng lượng"]
        retriever = self.retriever(self.chunks[:6])
        hits = retriever.search("synthetic", 5)
        promoted = next(h for h in hits if h["chunk_id"] == "fixture-5")
        supports = promoted["provenance"]["support_paths"]
        self.assertEqual({"fixture-0", "fixture-1"}, {p["seed_chunk_id"] for p in supports})
        self.assertEqual(2, len(supports))
        self.assertTrue(all(len(p["edge_path"]) == 2 for p in supports))
        self.assertEqual(hits, retriever.search("synthetic", 5))

    def test_budgets_and_filter_apply_to_seeds_as_well_as_expansion(self):
        retriever = self.retriever(self.chunks[:6], max_nodes=3, max_edges=2)
        hits = retriever.search("synthetic", 5)
        self.assertLessEqual(len(hits), 3)
        self.assertTrue(all(h["provenance"]["visited_nodes"] <= 3 and
                            h["provenance"]["edge_visits"] <= 2 for h in hits))
        self.assertEqual([], retriever.search("synthetic", filters={"source_revision_id": "other"}))

    def test_zero_support_weight_keeps_seed_ranking_for_ablation(self):
        for index in (0, 1, 5):
            self.chunks[index]["headings"] = ["CHƯƠNG BẰNG CHỨNG TỔNG HỢP"]
        hits = self.retriever(self.chunks[:6], support_weight=0).search("synthetic", 5)
        self.assertEqual([c["chunk_id"] for c in self.chunks[:5]], [h["chunk_id"] for h in hits])

    def test_invalid_fusion_parameters_are_rejected(self):
        for kwargs in ({"support_weight": -1}, {"support_weight": float("nan")},
                       {"hop_decay": 0}, {"hop_decay": True}, {"rrf_k": True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ManualGraphError):
                self.retriever(self.chunks[:1], **kwargs)

    def test_diagnostics_count_real_two_hop_connectivity_not_self_cycles(self):
        for index in (0, 1, 5):
            self.chunks[index]["headings"] = ["CHƯƠNG BẰNG CHỨNG TỔNG HỢP"]
        candidate = build_graph_candidate(self.chunks, self.freeze)
        report = inspect_graph(candidate, self.freeze)
        self.assertEqual(1, report["shared_topic_count"])
        self.assertEqual(3, report["chunks_reaching_another_chunk_in_two_hops"])
        self.assertEqual(6, report["directed_two_hop_chunk_pairs"])
        self.assertEqual(5, report["component_count"])
        self.assertEqual(3, report["largest_component_chunk_count"])
        self.assertFalse(report["release_ready"])


if __name__ == "__main__":
    unittest.main()
