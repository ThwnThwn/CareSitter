from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import statistics
import unicodedata
from typing import Any, Callable, Iterable

from .errors import ManualGraphError
from .jsonio import content_sha256
from .rights import resolve_source

TOKEN_PATTERN = re.compile(r"\w+|[^\w\s]", re.UNICODE)
HEADING_NUMBER_PATTERN = re.compile(
    r"^(?:[IVXLC]+\.|\d+\.|\d+(?:\.\d+)+(?:\.)?)[ \t]+\S", re.IGNORECASE
)
PRINTED_PAGE_PATTERN = re.compile(r"(?:^|\s)(\d{1,4})(?:\s|$)")
BOOK_HEADER_PATTERN = re.compile(r"^(?:DINH DƯỠNG LÂM SÀNG\s*\d*|\d+\s*DINH DƯỠNG LÂM SÀNG)$", re.IGNORECASE)


def lexical_tokens(text: str) -> list[str]:
    return TOKEN_PATTERN.findall(text)


def normalize_text(text: str) -> str:
    value = unicodedata.normalize("NFC", text.replace("\u00a0", " "))
    value = value.replace("\u200b", "").replace("\ufeff", "")
    return "\n".join(line.rstrip() for line in value.splitlines())


def _is_heading(text: str) -> bool:
    stripped = text.strip()
    if not stripped or len(stripped) > 150:
        return False
    letters = [character for character in stripped if character.isalpha()]
    uppercase_ratio = sum(character.isupper() for character in letters) / max(1, len(letters))
    return HEADING_NUMBER_PATTERN.match(stripped) is not None or (len(letters) >= 4 and uppercase_ratio >= 0.72)


def _is_table_block(lines: list[str]) -> bool:
    if len(lines) < 2:
        return False
    column_lines = sum(len(re.split(r"\s{2,}", line.strip())) >= 2 for line in lines)
    numeric_lines = sum(bool(re.search(r"\d", line)) for line in lines)
    return column_lines / len(lines) >= 0.4 and numeric_lines / len(lines) >= 0.4


def _printed_page_label(lines: list[str]) -> str | None:
    candidates = [line.strip() for line in lines[:3] + lines[-3:] if line.strip()]
    for line in reversed(candidates):
        matches = PRINTED_PAGE_PATTERN.findall(line)
        if matches:
            return matches[-1]
    return None


def _page_blocks(layout_text: str) -> tuple[list[dict[str, str]], str | None]:
    normalized = normalize_text(layout_text)
    raw_lines = normalized.splitlines()
    printed_page = _printed_page_label(raw_lines)
    retained: list[str] = []
    for raw_line in raw_lines:
        stripped = raw_line.strip()
        if stripped.isdigit() or BOOK_HEADER_PATTERN.fullmatch(stripped):
            retained.append("")
            continue
        retained.append(raw_line)

    groups: list[list[str]] = []
    current: list[str] = []
    for line in retained:
        if not line.strip():
            if current:
                groups.append(current)
                current = []
            continue
        stripped = re.sub(r"\s+", " ", line.strip())
        if _is_heading(stripped):
            if current:
                groups.append(current)
                current = []
            groups.append([stripped])
            continue
        current.append(line)
    if current:
        groups.append(current)

    blocks: list[dict[str, str]] = []
    for lines in groups:
        cleaned = [re.sub(r"\s+", " ", line.strip()) for line in lines if line.strip()]
        if not cleaned:
            continue
        kind = "heading" if len(cleaned) == 1 and _is_heading(cleaned[0]) else (
            "table_candidate" if _is_table_block(lines) else "paragraph"
        )
        separator = "\n" if kind == "table_candidate" else " "
        blocks.append({"kind": kind, "text": separator.join(cleaned)})
    return blocks, printed_page


def _split_large_block(block: dict[str, str], maximum_tokens: int) -> list[dict[str, str]]:
    if len(lexical_tokens(block["text"])) <= maximum_tokens:
        return [block]
    if block["kind"] == "table_candidate":
        units = block["text"].splitlines()
    else:
        units = re.split(r"(?<=[.!?;:])\s+", block["text"])
    parts: list[dict[str, str]] = []
    current: list[str] = []
    count = 0
    for unit in units:
        unit_count = len(lexical_tokens(unit))
        if current and count + unit_count > maximum_tokens:
            parts.append({**block, "text": "\n".join(current) if block["kind"] == "table_candidate" else " ".join(current)})
            current, count = [], 0
        if unit_count > maximum_tokens:
            tokens = lexical_tokens(unit)
            for offset in range(0, len(tokens), maximum_tokens):
                parts.append({**block, "text": " ".join(tokens[offset:offset + maximum_tokens])})
        else:
            current.append(unit)
            count += unit_count
    if current:
        parts.append({**block, "text": "\n".join(current) if block["kind"] == "table_candidate" else " ".join(current)})
    return parts


def chunk_blocks(
    *, source: dict[str, Any], blocks: list[dict[str, Any]], identity_scope: str,
    location_fields: Callable[[list[dict[str, Any]]], dict[str, Any]],
    target_tokens: int, maximum_tokens: int, overlap_tokens: int
) -> list[dict[str, Any]]:
    expanded = [part for block in blocks for part in _split_large_block(block, maximum_tokens)]
    chunks: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    current_count = 0
    for block in expanded:
        block_count = len(lexical_tokens(block["text"]))
        if current and current_count + block_count > maximum_tokens:
            chunks.append(current)
            carry: list[dict[str, Any]] = []
            carry_count = 0
            for previous in reversed(current):
                previous_count = len(lexical_tokens(previous["text"]))
                if carry and carry_count + previous_count > overlap_tokens:
                    break
                if previous_count <= overlap_tokens:
                    carry.insert(0, previous)
                    carry_count += previous_count
            current, current_count = carry, carry_count
            if current_count + block_count > maximum_tokens:
                current, current_count = [], 0
        current.append(block)
        current_count += block_count
        if current_count >= target_tokens:
            chunks.append(current)
            current, current_count = [], 0
    if current:
        current_tokens = sum(len(lexical_tokens(block["text"])) for block in current)
        previous_tokens = (
            sum(len(lexical_tokens(block["text"])) for block in chunks[-1]) if chunks else 0
        )
        if chunks and previous_tokens + current_tokens <= maximum_tokens:
            chunks[-1].extend(current)
        else:
            chunks.append(current)

    result: list[dict[str, Any]] = []
    for ordinal, chunk_blocks in enumerate(chunks, start=1):
        text = "\n\n".join(block["text"] for block in chunk_blocks).strip()
        if not text:
            continue
        token_count = len(lexical_tokens(text))
        kinds = Counter(block["kind"] for block in chunk_blocks)
        content_type = "table_candidate" if kinds["table_candidate"] > kinds["paragraph"] else "text"
        index_eligible = content_type == "text" and token_count >= 80
        review_status = "ready_for_retrieval_eval" if index_eligible else "manual_review_required"
        headings = [block["text"] for block in chunk_blocks if block["kind"] == "heading"]
        identity = f"{source['revision_id']}|{identity_scope}|{ordinal}|{text}".encode("utf-8")
        result.append({
            "schema_version": 1,
            "chunk_id": "nutrition-chunk-" + hashlib.sha256(identity).hexdigest()[:24],
            "source_id": source["source_id"],
            "source_revision_id": source["revision_id"],
            "source_sha256": source["sha256"],
            **location_fields(chunk_blocks),
            "chunk_ordinal_at_locator": ordinal,
            "content_type": content_type,
            "index_eligible": index_eligible,
            "review_status": review_status,
            "headings": headings,
            "tokenizer": "unicode_lexical_v1",
            "token_count": token_count,
            "text": text,
            "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
        })
    return result


def chunk_page(
    *, source: dict[str, Any], pdf_page: int, layout_text: str,
    target_tokens: int, maximum_tokens: int, overlap_tokens: int
) -> tuple[list[dict[str, Any]], str | None]:
    blocks, printed_page = _page_blocks(layout_text)
    result = chunk_blocks(
        source=source,
        blocks=blocks,
        identity_scope=f"pdf-page:{pdf_page}",
        location_fields=lambda _: {
            "source_locator": f"pdf-page:{pdf_page}",
            "pdf_page": pdf_page,
            "printed_page": printed_page,
            "chunk_ordinal_on_page": None,
        },
        target_tokens=target_tokens,
        maximum_tokens=maximum_tokens,
        overlap_tokens=overlap_tokens,
    )
    for ordinal, record in enumerate(result, start=1):
        record["chunk_ordinal_on_page"] = ordinal
    return result, printed_page


def chunk_pdf_source(
    *, workspace: Path, manifest_path: Path, source_id: str, output_path: Path,
    report_path: Path, target_tokens: int = 450, maximum_tokens: int = 700,
    overlap_tokens: int = 60
) -> dict[str, Any]:
    if not 100 <= target_tokens <= maximum_tokens <= 1200:
        raise ManualGraphError("chunk token settings must satisfy 100 <= target <= maximum <= 1200")
    if not 0 <= overlap_tokens < target_tokens:
        raise ManualGraphError("chunk overlap must be non-negative and smaller than target")
    source, pdf_path = resolve_source(
        workspace=workspace, manifest_path=manifest_path, source_id=source_id
    )
    if pdf_path.suffix.lower() != ".pdf":
        raise ManualGraphError("chunk-pdf requires a PDF source")
    try:
        import pdfplumber
    except ImportError as error:
        raise ManualGraphError("pdfplumber is required; install the tool dependencies") from error

    records: list[dict[str, Any]] = []
    skipped_pages: list[int] = []
    printed_page_count = 0
    with pdfplumber.open(pdf_path) as document:
        page_count = len(document.pages)
        for page_number, page in enumerate(document.pages, start=1):
            layout_text = page.extract_text(layout=True) or ""
            page_chunks, printed_page = chunk_page(
                source=source, pdf_page=page_number, layout_text=layout_text,
                target_tokens=target_tokens, maximum_tokens=maximum_tokens,
                overlap_tokens=overlap_tokens
            )
            if printed_page:
                printed_page_count += 1
            if not page_chunks:
                skipped_pages.append(page_number)
            records.extend(page_chunks)

    if not records:
        raise ManualGraphError("PDF extraction produced no chunks")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as stream:
        for record in records:
            stream.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
    temporary.replace(output_path)

    counts = [record["token_count"] for record in records]
    type_counts = Counter(record["content_type"] for record in records)
    review_counts = Counter(record["review_status"] for record in records)
    report = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_id": source["source_id"],
        "source_revision_id": source["revision_id"],
        "source_sha256": source["sha256"],
        "rights_status": source["rights_status"],
        "output_path": str(output_path.resolve()),
        "output_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
        "pdf_page_count": page_count,
        "chunk_count": len(records),
        "skipped_pages": skipped_pages,
        "printed_page_labels_detected": printed_page_count,
        "content_type_counts": dict(sorted(type_counts.items())),
        "review_status_counts": dict(sorted(review_counts.items())),
        "index_eligible_count": sum(record["index_eligible"] for record in records),
        "tokenizer": "unicode_lexical_v1",
        "target_tokens": target_tokens,
        "maximum_tokens": maximum_tokens,
        "overlap_tokens": overlap_tokens,
        "token_count_min": min(counts),
        "token_count_median": statistics.median(counts),
        "token_count_max": max(counts),
    }
    report["content_sha256"] = content_sha256({
        key: value for key, value in report.items() if key not in {"created_at_utc", "content_sha256"}
    })
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return report
