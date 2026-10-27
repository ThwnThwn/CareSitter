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

    def test_generated_questions_are_specific_and_never_cut_mid_word(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            chunks = load_retrieval_chunks(fixture.chunks_path)
            chunks[0]["headings"] = [
                "DINH DƯỠNG ĐIỀU TRỊ BỆNH A",
                "1. Khuyến nghị rất dài nhưng phải được rút gọn ở ranh giới từ thay vì cắt ngang chữ",
            ]
            chunks[0]["text"] = "Khuyến nghị 25 mg/ngày áp dụng cho người trưởng thành."
            chunks[1]["headings"] = ["DINH DƯỠNG ĐIỀU TRỊ BỆNH B", "2. Phạm vi điều trị"]
            chunks[1]["text"] = "Mức 30% áp dụng cho nhóm đối chứng."

            draft = build_visible_review_draft(fixture.cases(), chunks, fixture.freeze())
            numeric = [case for case in draft["cases"] if "numbers_units" in case.get("tags", [])]
            comparison = [case for case in draft["cases"] if "multi_hop" in case.get("tags", [])]

            self.assertTrue(any("25 mg/ngày" in case["question"] for case in numeric))
            self.assertFalse(any("các giá trị định lượng dùng đơn vị gì" in case["question"] for case in numeric))
            self.assertEqual(1, len(comparison))
            self.assertIn("DINH DƯỠNG ĐIỀU TRỊ BỆNH A", comparison[0]["question"])
            self.assertIn("DINH DƯỠNG ĐIỀU TRỊ BỆNH B", comparison[0]["question"])
            self.assertNotIn("có thể thay thế cho nhau", comparison[0]["question"])
            self.assertEqual(["multi_hop"], comparison[0]["tags"])
            self.assertTrue(any(
                set(case.get("tags", [])) == {"insufficient_evidence", "edition_conflict"}
                for case in draft["cases"]
            ))

    def test_numeric_question_uses_nearest_preceding_heading(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            chunks = load_retrieval_chunks(fixture.chunks_path)
            chunks[0]["headings"] = ["5. Sỏi mật", "6. Xơ gan", "7. Bệnh sâu răng"]
            chunks[0]["text"] = (
                "5. Sỏi mật\nNội dung không có số.\n\n"
                "6. Xơ gan\nLượng sử dụng giảm xuống 80 g/ngày.\n\n"
                "7. Bệnh sâu răng\nNội dung tiếp theo."
            )

            draft = build_visible_review_draft(fixture.cases(), chunks, fixture.freeze())
            numeric = next(case for case in draft["cases"] if "80 g/ngày" in case["question"])

            self.assertIn("6. Xơ gan", numeric["question"])
            self.assertNotIn("7. Bệnh sâu răng", numeric["question"])


if __name__ == "__main__":
    unittest.main()
