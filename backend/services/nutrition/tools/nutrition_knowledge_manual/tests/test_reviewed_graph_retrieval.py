import copy
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.graph_retriever import GraphRetriever
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrieval_graph import (build_graph_candidate, empty_graph_review,
    materialize_graph, record_graph_review, validate_candidate)
from nutrition_knowledge_manual.retrievers import cited_hit


class Seed:
    def __init__(self, chunk):
        self.chunk = chunk

    def search(self, question, top_k=5, filters=None):
        return [cited_hit(self.chunk, 1.0, "synthetic", {})]


def approve_graph(candidate, freeze):
    ledger = empty_graph_review(candidate, freeze)
    for rid in ledger["records"]:
        for role in ("data_steward", "dietitian"):
            ledger = record_graph_review(candidate, freeze, ledger, rid, "approved", "synthetic-" + role,
                                         role, "Synthetic test fixture only; not clinical evidence.")
    return ledger


class ReviewedGraphTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        fixture = _Fixture(Path(self.temp.name))
        self.freeze = fixture.freeze()
        self.chunks = load_retrieval_chunks(fixture.chunks_path)
        self.candidate = build_graph_candidate(self.chunks, self.freeze)

    def test_pending_candidates_never_enter_graph(self):
        ledger = empty_graph_review(self.candidate, self.freeze)
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        self.assertEqual([], graph["nodes"])
        self.assertEqual([], graph["edges"])
        with self.assertRaisesRegex(ManualGraphError, "reviewed edges"):
            GraphRetriever(Seed(self.chunks[0]), self.chunks, self.freeze, self.candidate, ledger, graph)

    def test_reviewed_graph_expands_two_hops_with_provenance_and_bounds(self):
        ledger = approve_graph(self.candidate, self.freeze)
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        retriever = GraphRetriever(Seed(self.chunks[0]), self.chunks, self.freeze, self.candidate, ledger, graph)
        hits = retriever.search("fixture")
        self.assertEqual({"eligible-a", "eligible-b"}, {h["chunk_id"] for h in hits})
        added = next(h for h in hits if h["chunk_id"] == "eligible-b")
        self.assertEqual(2, len(added["provenance"]["edge_path"]))
        limited = GraphRetriever(Seed(self.chunks[0]), self.chunks, self.freeze, self.candidate, ledger,
                                 graph, max_nodes=1, max_edges=1)
        self.assertEqual(1, len(limited.search("fixture")))

    def test_rejected_endpoint_prevents_materialization_of_approved_edge(self):
        ledger = approve_graph(self.candidate, self.freeze)
        ledger = record_graph_review(self.candidate, self.freeze, ledger, "eligible-b", "rejected",
                                      "synthetic-dietitian", "dietitian", "Reject fixture")
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        self.assertFalse(any("eligible-b" in (e["from"], e["to"]) for e in graph["edges"]))

    def test_rejected_seed_chunk_does_not_escape_the_reviewed_graph(self):
        ledger = approve_graph(self.candidate, self.freeze)
        ledger = record_graph_review(self.candidate, self.freeze, ledger, "eligible-b", "rejected",
                                      "synthetic-dietitian", "dietitian", "Reject fixture")
        graph = materialize_graph(self.candidate, self.freeze, ledger)

        retriever = GraphRetriever(Seed(self.chunks[1]), self.chunks, self.freeze,
                                   self.candidate, ledger, graph)

        self.assertEqual([], retriever.search("fixture"))

    def test_graph_and_ledger_tampering_revision_and_dangling_edges_fail(self):
        ledger = approve_graph(self.candidate, self.freeze)
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        graph["edges"].pop()
        with self.assertRaises(ManualGraphError):
            GraphRetriever(Seed(self.chunks[0]), self.chunks, self.freeze, self.candidate, ledger, sign(graph))
        for field, value in (("source_revision_id", "other"), ("evidence_chunk_ids", ["manual-c"]), ("to", "missing")):
            bad = copy.deepcopy(self.candidate)
            bad["edges"][0][field] = value
            with self.assertRaises(ManualGraphError):
                validate_candidate(sign(bad), self.freeze)
        changed = copy.deepcopy(self.candidate)
        changed["nodes"][0]["label"] = "modified after review"
        with self.assertRaisesRegex(ManualGraphError, "stale"):
            materialize_graph(sign(changed), self.freeze, ledger)

    def test_reversing_a_directed_edge_is_not_silently_accepted(self):
        changed = copy.deepcopy(self.candidate)
        edge = changed["edges"][0]
        edge["from"], edge["to"] = edge["to"], edge["from"]
        with self.assertRaisesRegex(ManualGraphError, "direction"):
            validate_candidate(sign(changed), self.freeze)

    def test_generic_headings_are_scoped_to_their_chapter(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = ["CHƯƠNG BỆNH A", "I. ĐẠI CƯƠNG"]
        chunks[1]["headings"] = ["CHƯƠNG BỆNH B", "I. ĐẠI CƯƠNG"]

        candidate = build_graph_candidate(chunks, self.freeze)
        topics = [node for node in candidate["nodes"] if node["type"] == "topic"]
        labels = {node["label"] for node in topics}

        self.assertIn("CHƯƠNG BỆNH A > I. ĐẠI CƯƠNG", labels)
        self.assertIn("CHƯƠNG BỆNH B > I. ĐẠI CƯƠNG", labels)
        self.assertNotIn("I. ĐẠI CƯƠNG", labels)
        self.assertFalse(any(set(node["evidence_chunk_ids"]) == {"eligible-a", "eligible-b"} for node in topics))

    def test_filtered_generic_root_still_scopes_specific_descendants(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = ["III. CHẾ ĐỘ DINH DƯỠNG", "2. Nguyên tắc chế độ dinh dưỡng"]
        chunks[1]["headings"] = ["2. Nguyên tắc chế độ dinh dưỡng"]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = {node["label"] for node in candidate["nodes"] if node["type"] == "topic"}

        self.assertIn("III. CHẾ ĐỘ DINH DƯỠNG > 2. Nguyên tắc chế độ dinh dưỡng", labels)
        self.assertNotIn("2. Nguyên tắc chế độ dinh dưỡng", labels)

    def test_numbered_siblings_do_not_become_parent_and_child(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = [
            "DINH DƯỠNG ĐIỀU TRỊ BỎNG",
            "II. CHUYỂN HÓA",
            "2.2. Chuyển hoá glucid",
            "2.3. Chuyển hoá lipid",
        ]
        chunks[1]["headings"] = ["2.4. Chuyển hoá protein"]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = {node["label"] for node in candidate["nodes"] if node["type"] == "topic"}

        prefix = "DINH DƯỠNG ĐIỀU TRỊ BỎNG > II. CHUYỂN HÓA > "
        self.assertIn(prefix + "2.2. Chuyển hoá glucid", labels)
        self.assertIn(prefix + "2.3. Chuyển hoá lipid", labels)
        self.assertIn(prefix + "2.4. Chuyển hoá protein", labels)
        self.assertFalse(any("2.2. Chuyển hoá glucid > 2.3." in label for label in labels))

    def test_table_headers_do_not_replace_chapter_or_poison_numbered_ancestry(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = [
            "DINH DƯỠNG CHO BỆNH NHÂN NẶNG",
            "II. CHIẾN LƯỢC CAN THIỆP",
            "2.1. Nuôi ăn qua đường tiêu hóa sớm",
            "Điểm TÌNH TRẠNG DINH DƯỠNG",
            "ĐỘ NẶNG CỦA BỆNH TĂNG NHU CẦU DINH DƯỠNG",
            "1 TUỔI ≥70",
        ]
        chunks[1]["headings"] = ["2.2. Ổn định đường huyết", "2.3. Nuôi dưỡng", "2.3.3. Nuôi tĩnh mạch"]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = {node["label"] for node in candidate["nodes"] if node["type"] == "topic"}

        self.assertFalse(any("TÌNH TRẠNG DINH DƯỠNG" in label for label in labels))
        self.assertFalse(any("1 TUỔI ≥70" in label for label in labels))
        self.assertIn(
            "DINH DƯỠNG CHO BỆNH NHÂN NẶNG > II. CHIẾN LƯỢC CAN THIỆP > "
            "2.3. Nuôi dưỡng > 2.3.3. Nuôi tĩnh mạch",
            labels,
        )

    def test_reference_sections_and_contributor_names_do_not_become_topics(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = [
            "CHƯƠNG BỆNH A",
            "VI. TÀI LIỆU THAM KHẢO",
            "1. WHO. Clinical nutrition guideline (2020).",
        ]
        chunks[1]["headings"] = [
            "BSCK1. NGUYỄN VĂN A",
            "25. Sylvia ES. Nutrition and diagnosis-related care. Seventh edition.",
            "12e ISBN: 978-0-8089-2378; 1037-1041.",
            "DINH DƯỠNG ĐIỀU TRỊ",
        ]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = [node["label"] for node in candidate["nodes"] if node["type"] == "topic"]

        self.assertEqual(["CHƯƠNG BỆNH A"], labels)

    def test_sentence_like_list_items_and_ocr_tokens_do_not_become_topics(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = [
            "CHƯƠNG BỆNH A",
            "1. Tăng cường đầu tư cho các can thiệp đã được chứng minh hiệu quả, chi phí hợp lý và bền vững",
        ]
        chunks[1]["headings"] = ["A B C D"]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = [node["label"] for node in candidate["nodes"] if node["type"] == "topic"]

        self.assertEqual(["CHƯƠNG BỆNH A"], labels)

    def test_menu_appendices_and_numeric_thresholds_do_not_become_topics(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = [
            "DINH DƯỠNG CHO BỆNH NHÂN NẶNG",
            "12.000 hoặc < 4.000 hoặc có >10% band Neutrophiles",
        ]
        chunks[1]["headings"] = [
            "DINH DƯỠNG ĐIỀU TRỊ BỆNH TĂNG HUYẾT ÁP",
            "V. LỰA CHỌN THỰC PHẨM VÀ THỰC ĐƠN THAM KHẢO",
        ]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = {node["label"] for node in candidate["nodes"] if node["type"] == "topic"}

        self.assertEqual({
            "DINH DƯỠNG CHO BỆNH NHÂN NẶNG",
            "DINH DƯỠNG ĐIỀU TRỊ BỆNH TĂNG HUYẾT ÁP",
        }, labels)

    def test_ambiguous_ocr_roots_do_not_replace_known_chapter_context(self):
        chunks = copy.deepcopy(self.chunks)
        chunks[0]["headings"] = ["DINH DƯỠNG ĐIỀU TRỊ BỆNH UNG THƯ", "III. CAN THIỆP"]
        chunks[1]["headings"] = ["GIẢM CÂN", "IV. CHẾ ĐỘ DINH DƯỠNG"]

        candidate = build_graph_candidate(chunks, self.freeze)
        labels = {node["label"] for node in candidate["nodes"] if node["type"] == "topic"}

        self.assertNotIn("GIẢM CÂN", labels)
        self.assertIn(
            "DINH DƯỠNG ĐIỀU TRỊ BỆNH UNG THƯ > IV. CHẾ ĐỘ DINH DƯỠNG",
            labels,
        )

        chunks[1]["headings"] = ["α, IL-1,IL-6", "IV. CHẾ ĐỘ DINH DƯỠNG"]
        candidate = build_graph_candidate(chunks, self.freeze)
        labels = {node["label"] for node in candidate["nodes"] if node["type"] == "topic"}

        self.assertFalse(any(label.startswith("α, IL-1,IL-6") for label in labels))
        self.assertIn(
            "DINH DƯỠNG ĐIỀU TRỊ BỆNH UNG THƯ > IV. CHẾ ĐỘ DINH DƯỠNG",
            labels,
        )


if __name__ == "__main__":
    unittest.main()
