"""Prepare visible review work from the PDF corpus, without granting any approval."""
from __future__ import annotations

from copy import deepcopy
import re

from .errors import ManualGraphError
from .retrieval_benchmark import COVERAGE_TAGS, validate_cases


def build_visible_review_draft(pilot: dict, chunks: list[dict], corpus_freeze: dict) -> dict:
    if pilot.get("corpus", {}).get("corpus_freeze_sha256") != corpus_freeze["content_sha256"]:
        raise ManualGraphError("review draft pilot has a different corpus binding")
    validate_cases(pilot["cases"], chunks, {"development", "validation"})
    result = deepcopy(pilot)
    result["status"], result["holdout_status"] = "pilot_visible", "not_created"
    result["provenance"] = {"authoring_method": "developer_visible_pdf_review_draft_v1",
        "clinical_review": "pending", "independent_holdout": False,
        "warning": "Câu hỏi, nhãn đáp án và citation chỉ là đề xuất để chuyên gia kiểm tra; không phải gold."}
    result.pop("evaluation_policy", None)
    result["cases"] = []
    for case in pilot["cases"]:
        copied = deepcopy(case)
        copied["review_status"] = "candidate"
        copied.pop("review", None)
        result["cases"].append(copied)
    lookup = {c["chunk_id"]: c for c in chunks}

    def append(kind, number, question, refs, tags):
        if any(" ".join(c["question"].casefold().split()) == " ".join(question[:500].casefold().split())
               for c in result["cases"]):
            return  # Repeated headings do not create independent evaluation questions.
        result["cases"].append({"case_id": f"pdf-draft-{kind}-{number + 1:02}",
            "question": question[:500], "split": "development" if number < 4 else "validation",
            "answerability": "answerable" if refs else "insufficient_evidence",
            "relevant_chunk_ids": refs, "tags": tags, "review_status": "candidate",
            "authoring_note": "Đề xuất tự động từ PDF; cần kiểm trang gốc, đơn vị, phạm vi và đủ evidence."})

    numeric = [c for c in chunks if c.get("headings") and re.search(r"\d[\d., -]*\s*(?:kcal|mg|g/kg|gam|gram|%)", c["text"], re.I)][:8]
    for i, chunk in enumerate(numeric):
        heading = str(chunk["headings"][0])[:150]
        append("numeric", i, f"Trong phần {heading}, các giá trị định lượng dùng đơn vị gì và áp dụng cho đối tượng nào?",
               [chunk["chunk_id"]], ["numbers_units"])
    answerable = [c for c in pilot["cases"] if c["answerability"] == "answerable"]
    for i in range(min(8, len(answerable) // 2)):
        left, right = answerable[2 * i], answerable[2 * i + 1]
        refs = list(dict.fromkeys(left["relevant_chunk_ids"] + right["relevant_chunk_ids"]))
        if len(refs) < 2:
            continue
        headings = ["; ".join(lookup[cid].get("headings") or [lookup[cid]["source_locator"]])[:130] for cid in (refs[0], refs[-1])]
        append("compare", i, f"Cần đối chiếu mục {headings[0]} với mục {headings[1]}: mỗi mục nói về phạm vi nào và có thể dùng thay cho nhau không?",
               refs, ["multi_hop", "edition_conflict"])
    for i, case in enumerate(answerable[:8]):
        chunk = lookup[case["relevant_chunk_ids"][0]]
        heading = "; ".join(chunk.get("headings") or [chunk["source_locator"]])[:160]
        append("abstain", i, f"Bản cập nhật năm 2026 của chính cuốn sách này đã sửa các khuyến nghị trong mục {heading} cụ thể thế nào?",
               [], ["insufficient_evidence"])
    validate_cases(result["cases"], chunks, {"development", "validation"})
    result["draft_coverage"] = {tag: sum(tag in c.get("tags", []) for c in result["cases"]) for tag in COVERAGE_TAGS}
    return result
