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


if __name__ == "__main__":
    unittest.main()
