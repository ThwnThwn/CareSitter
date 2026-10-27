"""Synthetic release fixtures; no reviewer identity or clinical approval is asserted."""
from argparse import Namespace
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.released_search import ReleasedEvidenceSearch
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.retrieval_pipeline_cli import _search
from nutrition_knowledge_manual.retrievers import cited_hit
from nutrition_knowledge_manual.jsonio import write_json
import test_retrieval_release_pipeline as release_fixture


def _manifest(ready=True):
    return sign({"schema_version": 1, "mode": "retrieval_release_manifest",
                 "release_ready": ready, "decision": "simplest_strategy_passing_all_gates" if ready else "no_go",
                 "scope": "M4_local_retrieval_evidence_only", "runtime_integration_authorized": False,
                 "gate_failures": [] if ready else ["review.pending"],
                 "selected_strategy": "keyword" if ready else None,
                 "bindings": {"corpus_freeze_sha256": "fixture-freeze"}})


def _chunk():
    return {"chunk_id": "fixture-chunk", "index_eligible": True,
            "review_status": "ready_for_retrieval_eval", "source_revision_id": "book-2019@fixture",
            "source_locator": "pdf-page:12", "pdf_page": 12, "printed_page": "11",
            "text": "Mục nguồn ở trang 11. Nội dung để kiểm tra trích dẫn.", "text_sha256": "fixture-text"}


class Seed:
    def __init__(self, chunk, overrides=None):
        self.chunk, self.overrides = chunk, overrides or {}

    def search(self, question, top_k=5, filters=None):
        return [{**cited_hit(self.chunk, 1.0, "keyword", {}), **self.overrides}]


class ReleasedEvidenceSearchTests(unittest.TestCase):
    def test_internal_search_returns_only_bounded_cited_excerpts(self):
        manifest, chunk = _manifest(), _chunk()
        search = ReleasedEvidenceSearch(manifest=manifest, rebuilt_manifest=manifest,
                                        chunks=[chunk], retriever=Seed(chunk, {"uncited_payload": "omit"}))

        result = search.search("Mục nguồn", top_k=1)

        self.assertEqual("released_internal_cited_search", result["mode"])
        self.assertEqual("pdf-page:12", result["hits"][0]["source_locator"])
        self.assertEqual("11", result["hits"][0]["printed_page"])
        self.assertEqual(chunk["text"], result["hits"][0]["text_preview"])
        self.assertEqual("fixture-text", result["hits"][0]["text_sha256"])
        self.assertNotIn("uncited_payload", result["hits"][0])
        with self.assertRaisesRegex(ManualGraphError, "at most 10"):
            search.search("Mục nguồn", top_k=11)

    def test_no_go_stale_or_uncited_result_is_rejected(self):
        chunk = _chunk()
        with self.assertRaisesRegex(ManualGraphError, "not ready"):
            ReleasedEvidenceSearch(manifest=_manifest(False), rebuilt_manifest=_manifest(False),
                                   chunks=[chunk], retriever=Seed(chunk))
        with self.assertRaisesRegex(ManualGraphError, "no longer matches"):
            ReleasedEvidenceSearch(manifest=_manifest(), rebuilt_manifest=sign({**_manifest(),
                                   "visible_review_sha256": "changed"}),
                                   chunks=[chunk], retriever=Seed(chunk))
        for altered in ({"source_locator": "pdf-page:99"}, {"chunk_id": "unknown"},
                        {"strategy": "graph"}):
            search = ReleasedEvidenceSearch(manifest=_manifest(), rebuilt_manifest=_manifest(),
                                            chunks=[chunk], retriever=Seed(chunk, altered))
            with self.assertRaisesRegex(ManualGraphError, "matching source evidence"):
                search.search("fixture")

    def test_cli_stops_on_no_go_before_loading_suite_or_model(self):
        with tempfile.TemporaryDirectory() as folder:
            workspace = Path(folder)
            path = workspace / "backend/artifacts/nutrition-knowledge-local/evaluation/release.json"
            path.parent.mkdir(parents=True)
            write_json(path, _manifest(False))
            with patch("nutrition_knowledge_manual.retrieval_pipeline_cli._suite") as suite:
                with self.assertRaisesRegex(ManualGraphError, "not ready"):
                    _search(Namespace(release_manifest=path), workspace)
                suite.assert_not_called()

    def test_cli_rebuilds_complete_synthetic_release_before_search(self):
        fixture = release_fixture.ReleasePipelineTests()
        fixture.setUp()
        try:
            report, _ = fixture.consume()
            manifest = fixture.release(report)
            self.assertTrue(manifest["release_ready"])
            root = fixture.workspace / "backend/artifacts/nutrition-knowledge-local/evaluation"
            root.mkdir(parents=True, exist_ok=True)
            documents = {"release_manifest": manifest, "cases": fixture.visible,
                         "visible_report": fixture.report, "review_ledger": fixture.ledger,
                         "corpus_freeze": fixture.corpus, "benchmark_freeze": fixture.plan,
                         "submission": fixture.submission, "holdout_ledger": fixture.holdout_ledger,
                         "holdout_report": report}
            paths = {}
            for name, document in documents.items():
                paths[name] = root / f"{name}.json"
                write_json(paths[name], document)
            args = Namespace(**paths, question="answerable fixture", top_k=1, source_revision_id=None)

            with patch("nutrition_knowledge_manual.retrieval_pipeline_cli._suite",
                       return_value=(fixture.chunks, {"keyword": Seed(fixture.chunks[0])},
                                     fixture.bindings)):
                result = _search(args, fixture.workspace)

            self.assertEqual("keyword", result["strategy"])
            self.assertEqual(fixture.chunks[0]["chunk_id"], result["hits"][0]["chunk_id"])
        finally:
            fixture.doCleanups()
