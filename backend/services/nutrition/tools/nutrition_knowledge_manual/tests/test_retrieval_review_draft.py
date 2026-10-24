from pathlib import Path
import tempfile
import unittest

from test_retrieval_review import _Fixture
from nutrition_knowledge_manual.retrieval_eval import load_retrieval_chunks
from nutrition_knowledge_manual.retrieval_review_draft import build_visible_review_draft


class ReviewDraftTests(unittest.TestCase):
    def test_draft_never_copies_approvals_or_claims_independence(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            pilot = fixture.cases()
            pilot["cases"][0]["review_status"] = "reviewed"
            pilot["cases"][0]["review"] = {"reviewer_id": "old-fixture-claim"}
            draft = build_visible_review_draft(pilot, load_retrieval_chunks(fixture.chunks_path), fixture.freeze())
            self.assertFalse(draft["provenance"]["independent_holdout"])
            self.assertEqual("not_created", draft["holdout_status"])
            self.assertTrue(all(c["review_status"] == "candidate" and "review" not in c for c in draft["cases"]))
            self.assertTrue(all(c["split"] != "holdout" for c in draft["cases"]))
            self.assertTrue(any(c["answerability"] == "insufficient_evidence" for c in draft["cases"]))


if __name__ == "__main__":
    unittest.main()
