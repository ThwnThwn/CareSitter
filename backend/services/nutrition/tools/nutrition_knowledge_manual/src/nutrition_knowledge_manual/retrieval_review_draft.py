"""Prepare visible review work from the PDF corpus, without granting any approval."""
from __future__ import annotations

from copy import deepcopy
import re

from .errors import ManualGraphError
from .retrieval_benchmark import COVERAGE_TAGS, validate_cases


_NUMERIC_VALUE = re.compile(
    r"(?<!\w)(\d+(?:[.,]\d+)?(?:\s*(?:-|–|đến)\s*\d+(?:[.,]\d+)?)?)"
    r"\s*(kcal/ngày|kcal|mg/ngày|mg|g/kg|g/ngày|gam|gram|%)\b",
    re.IGNORECASE,
)


def _compact_text(value: str, limit: int) -> str:
    """Collapse whitespace and shorten only at a word boundary."""
    normalized = " ".join(str(value).split())
    if len(normalized) <= limit:
        return normalized
    clipped = normalized[: limit - 1].rsplit(" ", 1)[0].rstrip(" ;,:-")
    return f"{clipped}…"


def _context_label(chunk: dict, limit: int = 180) -> str:
    headings = [" ".join(str(item).split()) for item in chunk.get("headings") or [] if str(item).strip()]
    if not headings:
        return _compact_text(chunk["source_locator"], limit)
    root, leaf = headings[0], headings[-1]
    label = root if root == leaf else f"{root} — {leaf}"
    return _compact_text(label, limit)


def _context_label_at(chunk: dict, offset: int, limit: int = 180) -> str:
    """Use the closest printed heading before a matched value inside a multi-section chunk."""
    text = str(chunk.get("text") or "")
    preceding: list[tuple[int, str]] = []
    for raw in chunk.get("headings") or []:
        heading = " ".join(str(raw).split())
        position = text.find(heading)
        if heading and 0 <= position <= offset:
            preceding.append((position, heading))
    if preceding:
        return _compact_text(max(preceding, key=lambda item: item[0])[1], limit)
    return _context_label(chunk, limit)


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

    numeric = [(chunk, _NUMERIC_VALUE.search(chunk["text"])) for chunk in chunks if chunk.get("headings")]
    numeric = [(chunk, match) for chunk, match in numeric if match is not None][:8]
    for i, (chunk, match) in enumerate(numeric):
        value = f"{match.group(1)} {match.group(2)}"
        page = chunk.get("printed_page") or chunk.get("pdf_page") or chunk["source_locator"]
        append("numeric", i,
               f"Ở trang {page}, trong mục “{_context_label_at(chunk, match.start())}”, số liệu “{value}” mô tả chỉ số hoặc đối tượng nào?",
               [chunk["chunk_id"]], ["numbers_units"])
    answerable = [c for c in pilot["cases"] if c["answerability"] == "answerable"]
    for i in range(min(8, len(answerable) // 2)):
        left, right = answerable[2 * i], answerable[2 * i + 1]
        refs = list(dict.fromkeys(left["relevant_chunk_ids"] + right["relevant_chunk_ids"]))
        if len(refs) < 2:
            continue
        headings = [_context_label(lookup[cid], 165) for cid in (refs[0], refs[-1])]
        append("compare", i,
               f"Đối chiếu “{headings[0]}” và “{headings[1]}”: mỗi mục trình bày phạm vi nội dung nào và nằm ở trang nào trong sách?",
               refs, ["multi_hop"])
    for i, case in enumerate(answerable[:8]):
        chunk = lookup[case["relevant_chunk_ids"][0]]
        heading = _context_label(chunk, 190)
        append("abstain", i, f"Bản cập nhật năm 2026 của chính cuốn sách này đã sửa các khuyến nghị trong mục “{heading}” cụ thể thế nào?",
               [], ["insufficient_evidence", "edition_conflict"])
    validate_cases(result["cases"], chunks, {"development", "validation"})
    result["draft_coverage"] = {tag: sum(tag in c.get("tags", []) for c in result["cases"]) for tag in COVERAGE_TAGS}
    return result
