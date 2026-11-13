"""Synthetic fixtures only; no real owner authorization or review is created."""
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from test_embedding_retrievers import FakeEncoder
from nutrition_knowledge_manual.candidate_benchmark import (
    CANDIDATE_MODE, CANDIDATE_REVIEW_STATUS, create_candidate_suite,
    validate_candidate_authorization)
from nutrition_knowledge_manual.embedding_index import build_embedding_index
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.graph_retriever import GraphRetriever
from nutrition_knowledge_manual.jsonio import file_sha256, write_json
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.retrieval_benchmark import benchmark, STRATEGIES
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrieval_graph import build_graph_candidate, empty_graph_review, materialize_graph
from nutrition_knowledge_manual.retrieval_release import (
    consume_holdout, freeze_benchmark, release_manifest, seal_for_benchmark, validate_benchmark_freeze,
    validate_report)
from nutrition_knowledge_manual.retrieval_suite import create_suite


class CandidateBenchmarkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fixture = _Fixture(self.root)
        self.freeze = self.fixture.freeze()
        self.chunks = load_retrieval_chunks(self.fixture.chunks_path)
        self.candidate = build_graph_candidate(self.chunks, self.freeze)
        self.path = self.root / "candidate.json"
        write_json(self.path, self.candidate)
        self.auth = sign({"schema_version": 1, "mode": "owner_authorized_graph_demo",
            "authorization_id": "synthetic-only", "authorization_basis": "Synthetic fixture only",
            "owner_accepted": True, "authorized_environment": "Development",
            "authorized_use": "academic_demo", "production_release_authorized": False,
            "independent_clinical_review": False, "graph_review_status": CANDIDATE_REVIEW_STATUS,
            "corpus_freeze_sha256": self.freeze["content_sha256"],
            "corpus_sha256": file_sha256(self.fixture.chunks_path), "graph_sha256": file_sha256(self.path)})
        self.config = {"schema_version": 2, "keyword_minimum_score": 0,
            "vector_minimum_score": 0, "rrf_k": 60, "fusion_candidates": 20,
            "graph_hops": 2, "graph_max_nodes": 200, "graph_max_edges": 500,
            "graph_support_weight": 1, "graph_hop_decay": .8}
        self.encoder = FakeEncoder()
        self.index = build_embedding_index(chunks_path=self.fixture.chunks_path,
            corpus_freeze=self.freeze, encoder=self.encoder, cache_dir=self.root / "cache")

    def validate(self, auth):
        return validate_candidate_authorization(authorization=auth, candidate_path=self.path,
            chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze)

    def suite(self):
        return create_candidate_suite(chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze,
            config=self.config, encoder=self.encoder, index=self.index,
            candidate_path=self.path, authorization=self.auth)

    def test_authorization_requires_integrity_explicit_scope_and_every_hash(self):
        for key, value in [("owner_accepted", False), ("owner_accepted", 1),
                ("authorized_environment", "Production"), ("authorized_use", "release"),
                ("production_release_authorized", True), ("independent_clinical_review", True),
                ("graph_review_status", "approved"), ("authorization_id", ""),
                ("authorization_basis", ""), ("graph_sha256", "0" * 64),
                ("corpus_sha256", "0" * 64), ("corpus_freeze_sha256", "0" * 64)]:
            with self.subTest(key=key, value=value):
                with self.assertRaises(ManualGraphError):
                    self.validate(sign({**self.auth, key: value}))
        for auth in [None, {}, {**self.auth, "owner_accepted": False}]:
            with self.assertRaises(ManualGraphError):
                self.validate(auth)
        self.assertEqual(self.candidate, self.validate(self.auth))

    def test_changed_candidate_or_corpus_is_rejected(self):
        self.path.write_text(self.path.read_text() + " ")
        with self.assertRaisesRegex(ManualGraphError, "hash mismatch"):
            self.validate(self.auth)
        write_json(self.path, self.candidate)
        with self.fixture.chunks_path.open("a") as stream:
            stream.write("\n")
        with self.assertRaisesRegex(ManualGraphError, "corpus freeze"):
            self.validate(self.auth)

    def test_candidate_matrix_is_explicit_and_does_not_admit_pending_to_reviewed_graph(self):
        chunks, retrievers, bindings = self.suite()
        report = benchmark(cases=self.fixture.cases(), chunks=chunks, retrievers=retrievers,
                           bindings=bindings, graph_candidate=True)
        self.assertEqual(CANDIDATE_MODE, report["mode"])
        self.assertEqual(CANDIDATE_REVIEW_STATUS, report["review_status"])
        self.assertFalse(report["release_ready"])
        self.assertEqual({"keyword", "vector", "hybrid", "graph-candidate"}, set(report["strategies"]))
        self.assertEqual(("keyword", "vector", "hybrid", "graph"), STRATEGIES)
        self.assertTrue(report["strategies"]["graph-candidate"]["results"])
        with self.assertRaises(ManualGraphError):
            benchmark(cases=self.fixture.cases(), chunks=chunks, retrievers=retrievers, bindings=bindings)
        with self.assertRaises(ManualGraphError):
            benchmark(cases=self.fixture.cases(), chunks=chunks, retrievers=retrievers,
                      bindings=bindings, graph_candidate=True, holdout=True)
        ledger = empty_graph_review(self.candidate, self.freeze)
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        self.assertEqual([], graph["edges"])
        with self.assertRaisesRegex(ManualGraphError, "reviewed edges"):
            GraphRetriever(retrievers["hybrid"], chunks, self.freeze, self.candidate, ledger, graph)
        _, normal, _ = create_suite(chunks_path=self.fixture.chunks_path,
            corpus_freeze=self.freeze, config=self.config, index=self.index, encoder=self.encoder)
        self.assertNotIn("graph-candidate", normal)

    def test_candidate_report_cannot_enter_freeze_release_or_holdout_even_relabelled(self):
        chunks, retrievers, bindings = self.suite()
        report = benchmark(cases=self.fixture.cases(), chunks=chunks, retrievers=retrievers,
                           bindings=bindings, graph_candidate=True)
        for artifact in [report, sign({**report, "mode": "paired_retrieval_benchmark"})]:
            with self.subTest(mode=artifact["mode"]):
                with self.assertRaisesRegex(ManualGraphError, "technical only"):
                    freeze_benchmark(report=artifact, cases=self.fixture.cases(), chunks=chunks,
                        bindings=bindings, corpus_freeze=self.freeze, ledger={}, developers=["synthetic"],
                        visible_evaluations=[])
                with self.assertRaisesRegex(ManualGraphError, "technical only"):
                    release_manifest(workspace=self.root, visible_report=artifact,
                        visible_cases=self.fixture.cases(), visible_ledger={}, corpus_freeze=self.freeze,
                        chunks=chunks, bindings=bindings)
                with self.assertRaisesRegex(ManualGraphError, "technical only"):
                    release_manifest(workspace=self.root, visible_report={}, holdout_report=artifact,
                        visible_cases={}, visible_ledger={}, corpus_freeze=self.freeze,
                        chunks=chunks, bindings={})
        forged = sign({"schema_version": 1, "mode": "retrieval_benchmark_freeze",
            "bindings": bindings, "selected_strategies": ["keyword"]})
        with self.assertRaisesRegex(ManualGraphError, "technical only"):
            validate_benchmark_freeze(forged, bindings)
        with self.assertRaisesRegex(ManualGraphError, "technical only"):
            seal_for_benchmark({}, self.freeze, [], forged)
        with self.assertRaisesRegex(ManualGraphError, "technical only"):
            consume_holdout(workspace=self.root, submission={}, marker={}, freeze=forged,
                corpus_freeze=self.freeze, ledger={}, chunks=chunks, retrievers=retrievers, bindings=bindings)
        with self.assertRaisesRegex(ManualGraphError, "cannot consume holdout"):
            consume_holdout(workspace=self.root, submission={}, marker={}, freeze={},
                corpus_freeze=self.freeze, ledger={}, chunks=chunks, retrievers=retrievers, bindings={})

    def test_candidate_requires_local_index(self):
        with self.assertRaisesRegex(ManualGraphError, "embedding index"):
            create_candidate_suite(chunks_path=self.fixture.chunks_path, corpus_freeze=self.freeze,
                config=self.config, encoder=None, index=None, candidate_path=self.path, authorization=self.auth)

    def test_each_candidate_marker_independently_blocks_release_validation(self):
        markers = [{"mode": CANDIDATE_MODE}, {"review_status": CANDIDATE_REVIEW_STATUS},
            {"strategies": {"graph-candidate": {}}}, {"selected_strategies": ["graph-candidate"]},
            {"bindings": {"candidate_demo_authorization_sha256": "synthetic"}}]
        for marker in markers:
            with self.subTest(marker=marker):
                with self.assertRaisesRegex(ManualGraphError, "technical only"):
                    validate_report(marker, {}, [], {})
                with self.assertRaisesRegex(ManualGraphError, "technical only"):
                    validate_benchmark_freeze(marker, {})

    def test_cli_candidate_authorization_is_only_available_for_visible_benchmark(self):
        from nutrition_knowledge_manual.cli import parser
        common = ["--workspace", str(self.root), "run-retrieval-benchmark",
            "--chunks", "chunks", "--corpus-freeze", "freeze", "--cases", "cases",
            "--config", "config", "--output", "output"]
        args = parser().parse_args(common + ["--graph-candidate-authorization", "authorization"])
        self.assertEqual(Path("authorization"), args.graph_candidate_authorization)
        self.assertIsNone(parser().parse_args(common).graph_candidate_authorization)
        # Other commands do not accept the demo opt-in at all.
        from contextlib import redirect_stderr
        from io import StringIO
        with redirect_stderr(StringIO()), self.assertRaises(SystemExit):
            parser().parse_args(["--workspace", str(self.root), "run-retrieval-holdout",
                "--graph-candidate-authorization", "authorization"])
