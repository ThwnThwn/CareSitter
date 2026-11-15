"""Synthetic checks for the local catalog evidence handoff; no clinical approval."""
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from nutrition_knowledge_manual.catalog_evidence import build_catalog_evidence_packet
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.retrieval_artifacts import verify
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrievers import KeywordRetriever, cited_hit


class CatalogEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        fixture = _Fixture(Path(self.temp.name))
        self.freeze = fixture.freeze()
        self.chunks = load_retrieval_chunks(fixture.chunks_path)
        self.claims = {"schema_version": 1, "claims": [
            {"candidate_id": "rule-1", "claim": "Dinh dưỡng A"},
            {"candidate_id": "rule-2", "claim": "zyxwv qponml"}]}

    def packet(self, claims=None, retriever=None):
        return build_catalog_evidence_packet(claims=claims or self.claims,
            chunks=self.chunks, retriever=retriever or KeywordRetriever(self.chunks),
            bindings={"corpus_freeze_sha256": self.freeze["content_sha256"]}, strategy="keyword")

    def test_only_eligible_cited_hits_enter_pending_review_packet(self):
        packet = self.packet()
        verify(packet, "catalog_evidence_review_packet")
        self.assertFalse(packet["release_ready"])
        self.assertEqual("pending", packet["claims"][0]["clinical_review"])
        self.assertEqual("candidate_hits_unverified", packet["claims"][0]["evidence_status"])
        self.assertTrue(packet["claims"][0]["evidence"][0]["excerpt"])
        self.assertEqual("no_evidence_found", packet["claims"][1]["evidence_status"])
        self.assertEqual([], packet["claims"][1]["evidence"])
        self.assertNotIn("manual-c", str(packet))

    def test_rejects_duplicate_claims_and_fabricated_citations(self):
        duplicate = {"schema_version": 1, "claims": [self.claims["claims"][0]] * 2}
        with self.assertRaisesRegex(ManualGraphError, "duplicated"):
            self.packet(duplicate)

        class FabricatedRetriever:
            def search(self, question, top_k):
                return [cited_hit({"chunk_id": "manual-c", "source_revision_id": "x",
                                   "source_locator": "fake"}, 1, "keyword", {})]

        with self.assertRaisesRegex(ManualGraphError, "ineligible"):
            self.packet(retriever=FabricatedRetriever())


if __name__ == "__main__":
    unittest.main()
