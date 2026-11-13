"""All reviews below are invented fixtures in temporary directories, never real approvals."""
import copy
from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
import test_retrieval_release_pipeline as pipeline
from test_catalog_authoring import _prepare, _profile
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import serialized_json_bytes, content_sha256
from nutrition_knowledge_manual.retrieval_artifacts import sign, verify
from nutrition_knowledge_manual.review_policy import DEFAULT, REFERENCE, REASON
from nutrition_knowledge_manual.retrieval_graph import build_graph_candidate, empty_graph_review, record_graph_review, materialize_graph
from nutrition_knowledge_manual.retrieval_review import empty_retrieval_review, record_retrieval_case_review
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.catalog_review import empty_catalog_review, record_recipe_review
from nutrition_knowledge_manual.catalog_authoring import finalize_catalog_candidate
from nutrition_knowledge_manual.retrieval_release import freeze_benchmark, seal_for_benchmark, consume_holdout, release_manifest
from nutrition_knowledge_manual.runtime_authorization import create_runtime_authorization, verify_runtime_authorization
from nutrition_knowledge_manual.review_batch import plan_review_import, apply_review_import, BATCH_MODE


class NonMedicalReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_graph_source_only_default_still_blocks_and_reference_filters_each_status(self):
        fixture = _Fixture(self.root)
        freeze = fixture.freeze()
        candidate = build_graph_candidate(load_retrieval_chunks(fixture.chunks_path), freeze)
        ledger = empty_graph_review(candidate, freeze)
        for rid in ledger["records"]:
            ledger = record_graph_review(candidate, freeze, ledger, rid, "approved", "synthetic-source",
                                         "data_steward", "Synthetic only", review_policy=REFERENCE)
        self.assertEqual([], materialize_graph(candidate, freeze, ledger)["nodes"])
        graph = materialize_graph(candidate, freeze, ledger, REFERENCE)
        self.assertEqual(len(candidate["nodes"]), len(graph["nodes"]))
        self.assertEqual(REASON, graph["clinical_review_not_performed_reason"])
        for status in (None, "rejected"):
            altered = copy.deepcopy(ledger)
            rid = candidate["nodes"][0]["id"]
            altered["records"][rid]["source_review"] = None if status is None else {
                **altered["records"][rid]["source_review"], "decision": status}
            filtered = materialize_graph(candidate, freeze, sign(altered), REFERENCE)
            self.assertNotIn(rid, {n["id"] for n in filtered["nodes"]})
            self.assertTrue(all(e["from"] != rid and e["to"] != rid for e in filtered["edges"]))
        for role in ("dietitian", "physician"):
            with self.assertRaises(ManualGraphError):
                record_graph_review(candidate, freeze, ledger, rid, "approved", "synthetic", role,
                                    "Synthetic", review_policy=REFERENCE)
            clinical = record_graph_review(candidate, freeze, ledger, rid, "approved", "synthetic", role, "Synthetic")
            with self.assertRaises(ManualGraphError):
                materialize_graph(candidate, freeze, clinical, REFERENCE)
        graph["review_policy"] = DEFAULT
        with self.assertRaises(ManualGraphError):
            verify(graph, "reviewed_retrieval_graph")

    def test_catalog_source_only_default_blocks_reference_excludes_pending_and_rejected(self):
        prepared = _prepare()
        manifest = prepared["manifest"]
        ledger = empty_catalog_review(manifest)
        ids = [r["recipe_version_id"] for r in manifest["recipe_candidates"]]
        for index, rid in enumerate(ids):
            ledger = record_recipe_review(candidate_manifest=manifest, ledger=ledger, recipe_version_id=rid,
                decision="approved", reviewer_id="synthetic-source",
                reviewer_role="data_steward", comment="Synthetic", review_policy=REFERENCE)
        kwargs = dict(profile=_profile(), candidate_manifest=manifest, candidate_bundle=prepared["bundle"],
                      candidate_evidence=prepared["evidence"], decisions=ledger)
        with self.assertRaisesRegex(ManualGraphError, "approved clinical"):
            finalize_catalog_candidate(**kwargs)
        ledger["decisions"][0]["data_review"] = None
        ledger["decisions"][1]["data_review"]["decision"] = "rejected"
        ledger = sign(ledger)
        kwargs["decisions"] = ledger
        output = finalize_catalog_candidate(**kwargs, review_policy=REFERENCE)
        self.assertEqual({row["recipe_version_id"] for row in ledger["decisions"][2:]},
                         {r["payload"]["versionId"] for r in output["bundle"]["recipes"]})
        self.assertIsNone(output["evidence"]["clinicalReview"])
        for row in output["evidence"]["recipes"]:
            review = row["dataReview"]
            self.assertEqual(("approved", "data_steward", "synthetic-source"),
                             (review["decision"], review["reviewerRole"], review["reviewerId"]))
            self.assertIn("+00:00", review["reviewedAt"])
        again = finalize_catalog_candidate(**{**kwargs, "decisions": ledger}, review_policy=REFERENCE)
        self.assertEqual(output["evidence"]["recipes"], again["evidence"]["recipes"])
        self.assertEqual(REFERENCE, output["bundle"]["review_policy"])
        self.assertEqual(content_sha256(output["bundle"]), output["manifest"]["artifacts"]["release_bundle"]["content_sha256"])
        for role in ("dietitian", "physician"):
            with self.assertRaises(ManualGraphError):
                record_recipe_review(candidate_manifest=manifest, ledger=ledger, recipe_version_id=ids[2],
                    decision="approved", reviewer_id="synthetic", reviewer_role=role, comment="Synthetic", review_policy=REFERENCE)
        altered = copy.deepcopy(output["manifest"])
        altered["production_public_release"] = True
        self.assertNotEqual(altered["content_sha256"], content_sha256({k:v for k,v in altered.items() if k != "content_sha256"}))

    def test_batch_policy_is_bound_to_dry_run_and_forbids_clinical_roles(self):
        fixture = _Fixture(self.root)
        freeze = fixture.freeze()
        candidate = build_graph_candidate(load_retrieval_chunks(fixture.chunks_path), freeze)
        ledger = empty_graph_review(candidate, freeze)
        rid, entry = next(iter(ledger["records"].items()))
        batch = {"schema_version": 1, "mode": BATCH_MODE, "target_kind": "graph",
            "corpus_freeze_sha256": freeze["content_sha256"], "target_content_sha256": candidate["content_sha256"],
            "ledger_content_sha256": ledger["content_sha256"], "reviewer_id": "synthetic-source",
            "reviewer_role": "data_steward", "decision_source": {"type": "completed_review_file", "reference": "synthetic", "attested": True},
            "decisions": [{"record_id": rid, "record_sha256": entry["record_sha256"], "decision": "approved", "comment": "Synthetic"}]}
        path = self.root / "batch.json"
        path.write_bytes(serialized_json_bytes(batch))
        kwargs = dict(target=candidate, corpus_freeze=freeze, ledger=ledger, batch=batch, batch_path=path)
        plan = plan_review_import(**kwargs, review_policy=REFERENCE)
        self.assertTrue(plan["can_apply"])
        with self.assertRaises(ManualGraphError):
            apply_review_import(**kwargs, plan=plan)
        applied = apply_review_import(**kwargs, plan=plan, review_policy=REFERENCE)
        self.assertIsNone(applied["records"][rid]["clinical_review"])
        for role in ("dietitian", "physician"):
            batch["reviewer_role"] = role
            with self.assertRaises(ManualGraphError):
                plan_review_import(**kwargs, review_policy=REFERENCE)

    def test_full_reference_release_keeps_holdout_independence_and_explicit_runtime_authorization(self):
        f = pipeline.ReleasePipelineTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        def source_only(ledger):
            result = copy.deepcopy(ledger)
            for row in result["decisions"]:
                row["clinical_relevance_review"] = None
            return sign(result)
        f.ledger = source_only(f.ledger)
        f.holdout_ledger = source_only(f.holdout_ledger)
        kwargs = dict(report=f.report, cases=f.visible, chunks=f.chunks, bindings=f.bindings,
            corpus_freeze=f.corpus, ledger=f.ledger, developers=["synthetic-developer"], visible_evaluations=[f.visible])
        with self.assertRaises(ManualGraphError):
            freeze_benchmark(**kwargs)
        blocked = release_manifest(workspace=f.workspace, visible_report=f.report, visible_cases=f.visible,
            visible_ledger=f.ledger, corpus_freeze=f.corpus, chunks=f.chunks, bindings=f.bindings)
        self.assertFalse(blocked["release_ready"])
        self.assertIn("review.pending_or_rejected", blocked["gate_failures"])
        plan = freeze_benchmark(**kwargs, review_policy=REFERENCE)
        f.submission["independence"]["author_role"] = "independent_author"
        f.holdout_ledger = empty_retrieval_review(cases=f.submission, corpus_freeze=f.corpus)
        for row in f.submission["cases"]:
            f.holdout_ledger = record_retrieval_case_review(cases=f.submission, corpus_freeze=f.corpus,
                ledger=f.holdout_ledger, case_id=row["case_id"], decision="approved", reviewer_id="synthetic-source",
                reviewer_role="data_steward", comment="Synthetic", review_policy=REFERENCE)
        marker = seal_for_benchmark(f.submission, f.corpus, [f.visible], plan, REFERENCE)
        report, _ = consume_holdout(workspace=f.workspace, submission=f.submission, marker=marker, freeze=plan,
            corpus_freeze=f.corpus, ledger=f.holdout_ledger, chunks=f.chunks, retrievers=f.retrievers,
            bindings=f.bindings, review_policy=REFERENCE)
        manifest = release_manifest(workspace=f.workspace, visible_report=f.report, visible_cases=f.visible,
            visible_ledger=f.ledger, corpus_freeze=f.corpus, chunks=f.chunks, bindings=f.bindings,
            freeze=plan, submission=f.submission, holdout_ledger=f.holdout_ledger, holdout_report=report, review_policy=REFERENCE)
        self.assertTrue(manifest["release_ready"])
        self.assertFalse(manifest["runtime_integration_authorized"])
        data = serialized_json_bytes(manifest)
        auth = create_runtime_authorization(data, environment="Staging", reviewer_id="synthetic", role="data_steward",
            comment="Synthetic only", review_policy=REFERENCE)
        verify_runtime_authorization(auth, data, environment="Staging")
        for role in ("dietitian", "physician"):
            with self.assertRaises(ManualGraphError):
                create_runtime_authorization(data, environment="Staging", reviewer_id="synthetic", role=role,
                    comment="Synthetic", review_policy=REFERENCE)
        with self.assertRaises(ManualGraphError):
            create_runtime_authorization(data, environment="Staging", reviewer_id="synthetic", role="data_steward", comment="Synthetic")
        for artifact, mode in ((manifest, "retrieval_release_manifest"), (auth, "runtime-integration-authorization")):
            artifact["intended_use"] = "altered"
            with self.assertRaises(ManualGraphError):
                verify(artifact, mode)
        f.submission["independence"]["author_id"] = "synthetic-developer"
        with self.assertRaisesRegex(ManualGraphError, "independent of developers"):
            seal_for_benchmark(f.submission, f.corpus, [f.visible], plan, REFERENCE)
