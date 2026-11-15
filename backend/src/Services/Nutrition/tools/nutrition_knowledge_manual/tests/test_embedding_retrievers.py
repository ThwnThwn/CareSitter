"""Synthetic deterministic vectors validate mechanics, never clinical quality."""
import copy
import json
from pathlib import Path
import tempfile
import unicodedata
import unittest
from unittest.mock import patch

from test_retrieval_review import _Fixture
from test_reviewed_graph_retrieval import approve_graph
from nutrition_knowledge_manual.embedding_index import build_embedding_index, validate_embedding_index
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.ollama_encoder import OllamaEncoder
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrieval_graph import build_graph_candidate, materialize_graph
from nutrition_knowledge_manual.retrieval_suite import create_suite
from nutrition_knowledge_manual.retrievers import EmbeddingRetriever, HybridRetriever, KeywordRetriever


class FakeEncoder:
    model, digest, dimension = "synthetic-test", "synthetic-digest", 3

    def __init__(self):
        self.calls = 0

    def encode(self, texts):
        self.calls += len(texts)
        return [[1.0, 0.25 if "A" in text else .75, .2] for text in texts]


class EmbeddingRetrieverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = _Fixture(Path(self.temp.name))
        self.freeze = self.fixture.freeze()
        self.chunks = load_retrieval_chunks(self.fixture.chunks_path)
        self.encoder = FakeEncoder()

    def build(self):
        return build_embedding_index(chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze,
                                     encoder=self.encoder, cache_dir=Path(self.temp.name) / "cache")

    def test_cache_is_reused_but_model_revision_invalidates_it(self):
        first = self.build()
        self.assertEqual(2, self.encoder.calls)
        self.assertEqual(first, self.build())
        self.assertEqual(2, self.encoder.calls)
        self.encoder.digest = "second-synthetic-digest"
        changed = self.build()
        self.assertEqual(4, self.encoder.calls)
        self.assertNotEqual(first["content_sha256"], changed["content_sha256"])
        with self.assertRaisesRegex(ManualGraphError, "revision"):
            validate_embedding_index(first, self.chunks, self.freeze, self.encoder)

    def test_index_rejects_missing_duplicate_manual_and_bad_vectors(self):
        index = self.build()
        mutations = [lambda r: r.pop(), lambda r: r.append(copy.deepcopy(r[0])),
                     lambda r: r[0].update(chunk_id="manual-c"),
                     lambda r: r[0].update(vector=[0, 0, 0]),
                     lambda r: r[0].update(vector=[1, 2]),
                     lambda r: r[0].update(vector=[float("nan"), 0, 1])]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                bad = copy.deepcopy(index)
                mutation(bad["records"])
                with self.assertRaises(ManualGraphError):
                    validate_embedding_index(sign(bad), self.chunks, self.freeze, self.encoder)

    def test_keyword_unicode_empty_filter_and_bound(self):
        keyword = KeywordRetriever(self.chunks)
        expected = keyword.search("Dinh dưỡng", 5)
        self.assertEqual(expected, keyword.search(unicodedata.normalize("NFD", "Dinh dưỡng"), 5))
        self.assertEqual(expected, keyword.search("dinh duong", 5))
        self.assertEqual([], keyword.search("", 5))
        self.assertEqual([], keyword.search("dinh duong", 5, {"source_revision_id": "other"}))
        self.assertEqual({"eligible-a", "eligible-b"}, {h["chunk_id"] for h in expected})
        with self.assertRaises(ManualGraphError):
            keyword.search("x" * 501)
        with self.assertRaises(ManualGraphError):
            keyword.search("x", filters={"patient": "ignored"})

    def test_vector_hybrid_citations_and_abstention(self):
        vector = EmbeddingRetriever(self.chunks, self.build(), self.freeze, self.encoder)
        hits = HybridRetriever(KeywordRetriever(self.chunks), vector).search("Dinh dưỡng A")
        self.assertEqual(2, len(hits))
        self.assertEqual("hybrid", hits[0]["strategy"])
        self.assertTrue(all(h["source_locator"] and h["provenance"]["ranks"] for h in hits))
        self.assertEqual([], vector.search(" "))
        self.assertEqual([], vector.search("A", filters={"source_revision_id": "other"}))

    def test_ollama_rejects_external_urls_credentials_redirect_and_digest_drift(self):
        for url in ("http://example.com", "http://localhost:11434", "http://127.0.0.1@evil.test",
                    "http://user:password@127.0.0.1", "http://127.0.0.1/api", "https://127.0.0.1"):
            with self.subTest(url=url), self.assertRaises(ManualGraphError):
                OllamaEncoder(url, "a" * 64)
        with patch.object(OllamaEncoder, "_request", return_value={"models": []}):
            with self.assertRaisesRegex(ManualGraphError, "digest"):
                OllamaEncoder("http://127.0.0.1:11434", "a" * 64)

    def test_versioned_suite_binds_and_applies_graph_fusion_parameters(self):
        config_path = Path(__file__).resolve().parents[1] / "config/retrieval.graph.v2.json"
        config = json.loads(config_path.read_text(encoding="utf-8"))
        config.update(graph_support_weight=0.0, graph_hop_decay=0.5)
        candidate = build_graph_candidate(self.chunks, self.freeze)
        ledger = approve_graph(candidate, self.freeze)
        graph = materialize_graph(candidate, self.freeze, ledger)
        _, suite, bindings = create_suite(chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze,
            config=config, encoder=self.encoder, index=self.build(), candidate=candidate, ledger=ledger, graph=graph)
        self.assertEqual(config, bindings["config"])
        hits = suite["graph"].search("Dinh dưỡng")
        self.assertTrue(hits)
        self.assertEqual(0.0, hits[0]["provenance"]["support_weight"])
        self.assertEqual(0.5, hits[0]["provenance"]["hop_decay"])
        legacy = {k: v for k, v in config.items() if k not in {"graph_support_weight", "graph_hop_decay"}}
        legacy["schema_version"] = 1
        _, legacy_suite, _ = create_suite(chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze,
                                          config=legacy)
        self.assertTrue(legacy_suite["keyword"].search("Dinh dưỡng"))
        for override in ({"graph_support_weight": -1}, {"graph_hop_decay": True}, {"schema_version": []}):
            with self.subTest(override=override), self.assertRaises(ManualGraphError):
                create_suite(chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze,
                             config=config | override)


if __name__ == "__main__":
    unittest.main()
