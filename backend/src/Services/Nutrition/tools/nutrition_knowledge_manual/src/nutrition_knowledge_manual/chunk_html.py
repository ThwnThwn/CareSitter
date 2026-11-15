from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
from html.parser import HTMLParser
import hashlib
import json
from pathlib import Path
import re
import statistics
from typing import Any

from .chunk_pdf import chunk_blocks, lexical_tokens, normalize_text
from .errors import ManualGraphError
from .jsonio import content_sha256
from .rights import resolve_source


BLOCK_TAGS = {"title", "h1", "h2", "h3", "h4", "h5", "h6", "p", "li", "tr"}
SKIP_TAGS = {"script", "style", "noscript", "svg", "nav", "header", "footer", "form"}
SCOPE_TAGS = {"main", "article", "section", "div"}
CONTENT_CLASS_TOKENS = {
    "article-content",
    "article-detail",
    "article-details",
    "entry-content",
    "news-description",
    "news-details",
    "post-content",
}


class _ContentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocks: list[dict[str, Any]] = []
        self._skip_depth = 0
        self._active_tag: str | None = None
        self._buffer: list[str] = []
        self._content_scope_stack: list[bool] = []
        self._content_scope_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag in SKIP_TAGS:
            self._skip_depth += 1
            return
        if self._skip_depth:
            return
        if tag in SCOPE_TAGS:
            class_tokens: set[str] = set()
            for name, value in attrs:
                if name.lower() == "class" and value:
                    class_tokens.update(value.lower().split())
            starts_content_scope = (
                tag in {"main", "article"}
                or bool(class_tokens.intersection(CONTENT_CLASS_TOKENS))
            )
            self._content_scope_stack.append(starts_content_scope)
            if starts_content_scope:
                self._content_scope_depth += 1
        if tag in BLOCK_TAGS and self._active_tag is None:
            self._active_tag = tag
            self._buffer = []
        elif tag in {"td", "th"} and self._active_tag == "tr" and self._buffer:
            self._buffer.append(" | ")
        elif tag == "br" and self._active_tag is not None:
            self._buffer.append("\n")

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in SKIP_TAGS:
            if self._skip_depth:
                self._skip_depth -= 1
            return
        if self._skip_depth:
            return
        if tag == self._active_tag:
            text = normalize_text("".join(self._buffer))
            text = re.sub(r"[ \t\r\f\v]+", " ", text)
            text = re.sub(r"\n\s*\n+", "\n", text).strip(" |\n")
            if text:
                kind = "heading" if tag in {"title", "h1", "h2", "h3", "h4", "h5", "h6"} else (
                    "table_candidate" if tag == "tr" else "paragraph"
                )
                self.blocks.append({
                    "kind": kind,
                    "text": text,
                    "html_block_ordinal": len(self.blocks) + 1,
                    "html_tag": tag,
                    "in_content_scope": self._content_scope_depth > 0,
                })
            self._active_tag = None
            self._buffer = []
        if tag in SCOPE_TAGS and self._content_scope_stack:
            ended_content_scope = self._content_scope_stack.pop()
            if ended_content_scope:
                self._content_scope_depth -= 1

    def handle_data(self, data: str) -> None:
        if not self._skip_depth and self._active_tag is not None:
            self._buffer.append(data)


def extract_html_blocks(html: str) -> list[dict[str, Any]]:
    parser = _ContentParser()
    parser.feed(html)
    parser.close()
    scoped = [block for block in parser.blocks if block["in_content_scope"]]
    selected = (
        [block for block in parser.blocks if block["html_tag"] == "title"] + scoped
        if scoped else parser.blocks
    )
    for ordinal, block in enumerate(selected, start=1):
        block["html_block_ordinal"] = ordinal
        block.pop("in_content_scope", None)
    return selected


def chunk_html_source(
    *, workspace: Path, manifest_path: Path, source_id: str, output_path: Path,
    report_path: Path, target_tokens: int = 450, maximum_tokens: int = 700,
    overlap_tokens: int = 60
) -> dict[str, Any]:
    if not 100 <= target_tokens <= maximum_tokens <= 1200:
        raise ManualGraphError("chunk token settings must satisfy 100 <= target <= maximum <= 1200")
    if not 0 <= overlap_tokens < target_tokens:
        raise ManualGraphError("chunk overlap must be non-negative and smaller than target")
    source, html_path = resolve_source(
        workspace=workspace, manifest_path=manifest_path, source_id=source_id
    )
    if html_path.suffix.lower() not in {".html", ".htm"}:
        raise ManualGraphError("chunk-html requires an HTML source")

    raw = html_path.read_text(encoding="utf-8", errors="strict")
    blocks = extract_html_blocks(raw)
    if not blocks:
        raise ManualGraphError("HTML extraction produced no content blocks")

    def location_fields(chunk: list[dict[str, Any]]) -> dict[str, Any]:
        ordinals = [int(item["html_block_ordinal"]) for item in chunk]
        first, last = min(ordinals), max(ordinals)
        return {
            "source_locator": f"html-blocks:{first}-{last}",
            "html_block_start": first,
            "html_block_end": last,
        }

    records = chunk_blocks(
        source=source,
        blocks=blocks,
        identity_scope="html-document",
        location_fields=location_fields,
        target_tokens=target_tokens,
        maximum_tokens=maximum_tokens,
        overlap_tokens=overlap_tokens,
    )
    if not records:
        raise ManualGraphError("HTML extraction produced no chunks")

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
        "document_format": "html",
        "output_path": str(output_path.resolve()),
        "output_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
        "html_block_count": len(blocks),
        "chunk_count": len(records),
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
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return report
