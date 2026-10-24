from __future__ import annotations

import copy
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "tests"))

from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.retrieval_holdout import (
    seal_independent_holdout,
    validate_sealed_independent_holdout,
)
from test_retrieval_review import _Fixture


class RetrievalHoldoutTests(unittest.TestCase):
    def test_only_new_independent_cases_can_be_sealed_and_marker_is_hash_bound(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            freeze = fixture.freeze()
            visible = fixture.cases()
            submission = _submission(freeze=freeze, count=10)

            sealed = seal_independent_holdout(
                submission=submission, corpus_freeze=freeze, visible_evaluations=[visible]
            )
            self.assertEqual("sealed_not_consumed", sealed["consumption_state"])
            self.assertFalse(sealed["release_ready"])
            self.assertEqual(10, sealed["case_count"])
            self.assertEqual(sealed, validate_sealed_independent_holdout(
                sealed_holdout=sealed, submission=submission, corpus_freeze=freeze
            ))

            changed = copy.deepcopy(submission)
            changed["cases"][0]["question"] = "Câu hỏi độc lập đã bị thay đổi."
            with self.assertRaisesRegex(ManualGraphError, "stale or tampered"):
                validate_sealed_independent_holdout(
                    sealed_holdout=sealed, submission=changed, corpus_freeze=freeze
                )

    def test_visible_pilot_cannot_be_relabelled_and_sealed_as_holdout(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            freeze = fixture.freeze()
            visible = fixture.cases()

            with self.assertRaisesRegex(ManualGraphError, "only a new independent holdout"):
                seal_independent_holdout(
                    submission=visible, corpus_freeze=freeze, visible_evaluations=[visible]
                )

            relabelled = _submission(freeze=freeze, count=10)
            relabelled["cases"][0]["question"] = visible["cases"][0]["question"]
            relabelled["cases"][0]["relevant_chunk_ids"] = visible["cases"][0]["relevant_chunk_ids"]
            with self.assertRaisesRegex(ManualGraphError, "reuses a visible"):
                seal_independent_holdout(
                    submission=relabelled, corpus_freeze=freeze, visible_evaluations=[visible]
                )


def _submission(*, freeze: dict, count: int) -> dict:
    cases = []
    for index in range(count):
        cases.append({
            "case_id": f"independent-holdout-{index + 1:02d}",
            "question": f"Câu hỏi độc lập số {index + 1} về chủ đề giả lập.",
            "split": "holdout",
            "answerability": "answerable",
            "relevant_chunk_ids": ["eligible-a" if index % 2 == 0 else "eligible-b"],
        })
    return {
        "schema_version": 1,
        "dataset_kind": "independent_holdout_submission",
        "holdout_status": "pending_seal",
        "corpus": {
            "source_revision_id": freeze["source_revision_id"],
            "chunks_sha256": freeze["chunks_sha256"],
            "corpus_freeze_sha256": freeze["content_sha256"],
        },
        "independence": {
            "author_id": "dietitian-independent-fixture",
            "author_role": "dietitian",
            "independently_authored": True,
            "attestation_note": "Synthetic test fixture only; this is not a clinical approval.",
        },
        "cases": cases,
    }


if __name__ == "__main__":
    unittest.main()
