"""Synthetic source-scope checks; these are not clinical evaluation cases."""
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import load_json
from nutrition_knowledge_manual.retrieval_suite import create_suite
from nutrition_knowledge_manual.source_edition_guard import SourceEditionGuard


class RecordingRetriever:
    def __init__(self):
        self.calls = 0

    def search(self, question, top_k=5, filters=None):
        self.calls += 1
        return [{"chunk_id": "synthetic"}]


class SourceEditionGuardTests(unittest.TestCase):
    def test_future_edition_abstains_without_calling_retriever(self):
        inner = RecordingRetriever()
        guard = SourceEditionGuard(inner, "book-clinical-nutrition-2019@sha256:fixture")
        for query in ("Bản cập nhật năm 2026 đã sửa gì?",
                      "So sánh ấn bản 2019 và 2026", "Ấn bản 2016 nói gì?",
                      "What changed in the revised edition 2026?"):
            self.assertEqual([], guard.search(query))
        self.assertEqual(0, inner.calls)

    def test_same_edition_and_non_edition_year_queries_pass_through(self):
        inner = RecordingRetriever()
        guard = SourceEditionGuard(inner, "book-clinical-nutrition-2019@sha256:fixture")
        self.assertEqual(1, len(guard.search("Ấn bản 2019 nói gì?")))
        self.assertEqual(1, len(guard.search("Đánh giá người sinh năm 2026 ở đâu?")))
        self.assertEqual(2, inner.calls)

    def test_unknown_source_year_abstains_on_edition_questions(self):
        inner = RecordingRetriever()
        guard = SourceEditionGuard(inner, "fixture-source@sha256:fixture")
        self.assertEqual([], guard.search("Bản cập nhật năm 2019 nói gì?"))
        self.assertEqual(0, inner.calls)
        with self.assertRaises(ManualGraphError):
            guard.search("x" * 501)

    def test_suite_applies_guard_to_keyword_strategy(self):
        class DatedFixture(_Fixture):
            source_id = "book-fixture-2019"
            revision_id = "book-fixture-2019@sha256:fixture"

        with tempfile.TemporaryDirectory() as folder:
            fixture = DatedFixture(Path(folder))
            freeze = fixture.freeze()
            config = load_json(Path(__file__).resolve().parents[1] / "retrieval-config.example.json")
            _, retrievers, _ = create_suite(chunks_path=fixture.chunks_path,
                                            corpus_freeze=freeze, config=config)
            self.assertEqual([], retrievers["keyword"].search("Bản cập nhật năm 2026 nói gì về dinh dưỡng?"))
            self.assertTrue(retrievers["keyword"].search("Nội dung phù hợp A ở đâu?"))


if __name__ == "__main__":
    unittest.main()
