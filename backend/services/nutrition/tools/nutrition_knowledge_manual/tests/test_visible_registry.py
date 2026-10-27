"""Synthetic fixtures only; no reviewer identity or review decision is asserted."""
from pathlib import Path
import tempfile
import unittest

from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256, load_json, write_json
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.visible_registry import (
    INVENTORY_MODE,
    _inside,
    build_repair_inventory,
    build_visible_registry,
    verify_visible_registry,
)

ROOT_A = "backend/artifacts/nutrition-knowledge-local/evaluation"
ROOT_B = "backend/services/nutrition/tools/nutrition_knowledge_manual/evaluation"
ROOTS = (ROOT_A, ROOT_B)
REVISION = "book@sha256:aaaa"


def _case(case_id, question, chunk="c1", answerability="answerable"):
    return {"case_id": case_id, "question": question, "answerability": answerability,
            "relevant_chunk_ids": [chunk], "split": "development"}


def _doc(cases, revision=REVISION):
    return {"corpus": {"source_revision_id": revision}, "cases": cases}


class VisibleRegistryTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.doc = _doc([_case("a", "Câu hỏi một?"), _case("b", "Câu hỏi hai?", "c2")])
        write_json(self.root / ROOT_A / "cases.v1.json", self.doc)

    def _build(self):
        return build_visible_registry(self.root, ROOTS)

    def test_same_input_same_registry_and_fingerprints(self):
        first, second = self._build(), self._build()
        self.assertEqual(first, second)
        self.assertEqual(first["visible_fingerprint_count"], 2)
        self.assertTrue(first["complete"])

    def test_fingerprint_ignores_case_id_and_question_spacing(self):
        write_json(self.root / ROOT_B / "copy.json", _doc([_case("zzz", "  câu   HỎI một? ")]))
        self.assertEqual(self._build()["visible_fingerprint_count"], 2)

    def test_same_question_on_different_source_revisions_is_distinct(self):
        write_json(self.root / ROOT_B / "other-revision.json",
                   _doc([_case("a", "Câu hỏi một?")], revision="book@sha256:bbbb"))
        registry = self._build()
        self.assertEqual(registry["visible_fingerprint_count"], 3)
        self.assertEqual({c["source_revision_id"] for c in registry["case_sets"]}, {REVISION, "book@sha256:bbbb"})

    def test_case_set_without_source_revision_is_incompatible(self):
        write_json(self.root / ROOT_B / "no-revision.json", {"cases": [_case("a", "Câu hỏi một?")]})
        registry = self._build()
        self.assertFalse(registry["complete"])
        self.assertEqual(len(registry["incompatible_case_files"]), 1)

    def test_malformed_chunk_ids_do_not_crash_scan(self):
        bad = _case("x", "Hỏi?")
        bad["relevant_chunk_ids"] = ["ok", 7]
        write_json(self.root / ROOT_B / "bad.json", _doc([bad]))
        registry = self._build()
        self.assertFalse(registry["complete"])
        self.assertEqual([i["path"] for i in registry["incompatible_case_files"]], [f"{ROOT_B}/bad.json"])

    def test_malformed_case_fields_do_not_crash_scan(self):
        for index, mutate in enumerate((lambda c: c.update(case_id=5), lambda c: c.update(split=3),
                                        lambda c: c.update(question="   "))):
            case = _case("x", "Hỏi?")
            mutate(case)
            write_json(self.root / ROOT_B / f"bad{index}.json", _doc([case]))
        self.assertEqual(len(self._build()["incompatible_case_files"]), 3)

    def test_changed_file_is_detected(self):
        registry = self._build()
        write_json(self.root / ROOT_A / "cases.v1.json", _doc([_case("a", "Khác hẳn?")]))
        result = verify_visible_registry(self.root, registry)
        self.assertEqual(result["status"], "drift")
        self.assertEqual(result["changed"], [f"{ROOT_A}/cases.v1.json"])

    def test_missing_and_new_files_are_detected(self):
        registry = self._build()
        (self.root / ROOT_A / "cases.v1.json").unlink()
        write_json(self.root / ROOT_A / "new.json", _doc([_case("n", "Mới?")]))
        result = verify_visible_registry(self.root, registry)
        self.assertEqual(result["missing"], [f"{ROOT_A}/cases.v1.json"])
        self.assertEqual(result["added"], [f"{ROOT_A}/new.json"])

    def test_unreadable_file_is_reported_not_ignored(self):
        (self.root / ROOT_A / "broken.json").write_text("{not json", encoding="utf-8")
        registry = self._build()
        self.assertFalse(registry["complete"])
        self.assertEqual([item["path"] for item in registry["unreadable"]], [f"{ROOT_A}/broken.json"])

    def test_orphan_reference_makes_registry_incomplete(self):
        write_json(self.root / ROOT_A / "packet.json", {"mode": "x", "evaluation_content_sha256": "0" * 64})
        registry = self._build()
        self.assertEqual(registry["orphan_references"], [f"{ROOT_A}/packet.json"])
        self.assertFalse(registry["complete"])

    def test_dependent_resolving_to_case_set_is_not_orphan(self):
        write_json(self.root / ROOT_A / "ledger.json",
                   {"mode": "x", "evaluation_content_sha256": content_sha256(self.doc)})
        self.assertTrue(self._build()["complete"])

    def test_incompatible_case_file_is_flagged(self):
        write_json(self.root / ROOT_A / "other.json", {"cases": [{"prompt": "x"}]})
        registry = self._build()
        self.assertFalse(registry["complete"])
        self.assertEqual(len(registry["incompatible_case_files"]), 1)

    def test_review_packet_with_cases_is_dependent_not_incompatible(self):
        write_json(self.root / ROOT_A / "packet.json", {
            "mode": "local_retrieval_review_packet", "evaluation_content_sha256": content_sha256(self.doc),
            "cases": [{"case_id": "a", "preview": "x"}]})
        registry = self._build()
        self.assertEqual(len(registry["dependent_artifacts"]), 1)
        self.assertEqual(registry["incompatible_case_files"], [])
        self.assertTrue(registry["complete"])

    def test_existing_registry_is_not_listed_as_input(self):
        registry = self._build()
        write_json(self.root / ROOT_A / "visible-registry.v1.json", registry)
        self.assertEqual(self._build()["content_sha256"], registry["content_sha256"])

    def test_path_cannot_escape_workspace(self):
        with self.assertRaises(ManualGraphError):
            _inside(self.root, "../outside.json")


class RepairInventoryTests(unittest.TestCase):
    FREEZE_PATH = "evaluation/x.retrieval-corpus-freeze.v1.json"
    INDEX_PATH = "indexes/x.index.v1.json"

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.freeze = {"content_sha256": "f" * 64, "eligible_chunk_count": 2,
                       "eligible_chunk_identities": [{"chunk_id": "a"}, {"chunk_id": "b"}]}
        self.index = {"corpus_freeze_sha256": "f" * 64, "records": [1, 2],
                      "model": {"model": "bge-m3:latest", "digest": "d" * 64}}
        write_json(self.root / ROOT_A / "cases.v1.json", _doc([_case("a", "Câu hỏi một?")]))
        self.registry_path = Path(ROOT_A) / "visible-registry.v1.json"
        self._write_inputs()
        self.registry_file = self.root / self.registry_path
        self.registry_file.parent.mkdir(parents=True, exist_ok=True)
        write_json(self.registry_file, build_visible_registry(self.root, ROOTS))
        self.base = self._base()

    def _write_inputs(self):
        write_json(self.root / self.FREEZE_PATH, self.freeze)
        write_json(self.root / self.INDEX_PATH, self.index)

    def _base(self):
        files = [{"path": p, "sha256": file_sha256(self.root / p)} for p in (self.FREEZE_PATH, self.INDEX_PATH)]
        return sign({"schema_version": 1, "mode": INVENTORY_MODE, "files": files, "code": {},
                     "pending_graph_records": 4186, "release_ready": False, "verification": {"tests_run": 1}})

    def _build(self):
        return build_repair_inventory(self.root, self.base, self.registry_path)

    def _rewrite_inputs(self, *, freeze=None, index=None):
        self.freeze = freeze or self.freeze
        self.index = index or self.index
        self._write_inputs()
        self.base = self._base()  # the previous inventory is consistent; only the checks may fail

    def test_builds_new_revision_with_registry_and_checks(self):
        result = self._build()
        self.assertEqual(result["checks"]["eligible_chunk_count"], 2)
        self.assertTrue(result["checks"]["index_matches_corpus_freeze"])
        self.assertEqual(result["previous_inventory_content_sha256"], self.base["content_sha256"])
        self.assertEqual(result["visible_registry_content_sha256"], load_json(self.registry_file)["content_sha256"])
        self.assertIn(self.registry_path.as_posix(), [item["path"] for item in result["files"]])
        self.assertNotIn("verification", result)  # old test counts are not carried to new code
        self.assertEqual(result, self._build())

    def test_next_inventory_revision_does_not_duplicate_same_registry_path(self):
        first = self._build()
        second = build_repair_inventory(self.root, first, self.registry_path)
        paths = [item["path"] for item in second["files"]]
        self.assertEqual(1, paths.count(self.registry_path.as_posix()))

    def test_changed_dependency_stops_build(self):
        write_json(self.root / self.FREEZE_PATH, {**self.freeze, "eligible_chunk_count": 3})
        with self.assertRaisesRegex(ManualGraphError, "changed:"):
            self._build()

    def test_missing_dependency_stops_build(self):
        (self.root / self.FREEZE_PATH).unlink()
        with self.assertRaisesRegex(ManualGraphError, "missing:"):
            self._build()

    def test_tampered_base_inventory_is_rejected(self):
        self.base = {**self.base, "pending_graph_records": 0}
        with self.assertRaises(ManualGraphError):
            self._build()

    def test_incomplete_registry_stops_build(self):
        (self.root / ROOT_B).mkdir(parents=True, exist_ok=True)
        (self.root / ROOT_B / "broken.json").write_text("{x", encoding="utf-8")
        write_json(self.registry_file, build_visible_registry(self.root, ROOTS))
        with self.assertRaisesRegex(ManualGraphError, "visible_registry_incomplete"):
            self._build()

    def test_stale_registry_stops_build(self):
        write_json(self.root / ROOT_A / "late.json", _doc([_case("late", "Mới thêm?")]))
        with self.assertRaisesRegex(ManualGraphError, "visible_registry_stale"):
            self._build()

    def test_tampered_registry_file_stops_build(self):
        registry = load_json(self.registry_file)
        registry["visible_fingerprint_count"] = 99
        write_json(self.registry_file, registry)
        with self.assertRaises(ManualGraphError):
            self._build()

    def test_index_for_other_freeze_stops_build(self):
        self._rewrite_inputs(index={**self.index, "corpus_freeze_sha256": "e" * 64})
        with self.assertRaisesRegex(ManualGraphError, "index_corpus_freeze_mismatch"):
            self._build()

    def test_unequal_counts_stop_build(self):
        self._rewrite_inputs(freeze={**self.freeze, "eligible_chunk_count": 3})
        with self.assertRaisesRegex(ManualGraphError, "count_mismatch"):
            self._build()
        self._rewrite_inputs(index={**self.index, "records": [1]})
        with self.assertRaisesRegex(ManualGraphError, "count_mismatch"):
            self._build()

    def test_unpinned_model_digest_stops_build(self):
        for model in ({"model": "bge-m3:latest", "digest": "short"},
                      {"model": "other:latest", "digest": "d" * 64},
                      {"model": "bge-m3:latest", "digest": "D" * 64}):
            self._rewrite_inputs(index={**self.index, "model": model})
            with self.assertRaisesRegex(ManualGraphError, "index_model_not_pinned"):
                self._build()

    def test_registry_outside_workspace_is_rejected(self):
        with self.assertRaises(ManualGraphError):
            build_repair_inventory(self.root, self.base, Path("../registry.json"))


if __name__ == "__main__":
    unittest.main()
