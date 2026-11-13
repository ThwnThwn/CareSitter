"""Local-only PDF heading checks. Output contains metadata, never book paragraphs."""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

from .chunk_pdf import _page_blocks
from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json
from .retrieval_artifacts import local_path, sign, verify, write_once_atomic
from .retrieval_graph import _normalized_heading, _topic_paths, validate_candidate
from .review_batch import EXPORT_MODE
from .rights import resolve_source

MODE = "local_graph_source_check"
INSTRUCTIONS = (
    "Chỉ sửa decision (approved/rejected), comment bắt buộc và reviewer_id. "
    "Để trống cả ba khi chưa duyệt. Chỉ điền cả nhóm sau khi kiểm nhóm đó. "
    "auto_check chỉ tham khảo cấu trúc, không phải duyệt nguồn/chuyên môn."
)


def pdf_outline(pdf_path: Path) -> dict[int, dict]:
    """Read every page locally so excluded pages still break continuation scopes."""
    import pdfplumber

    pages = {}
    context = []
    with pdfplumber.open(pdf_path) as document:
        for number, page in enumerate(document.pages, 1):
            blocks, _ = _page_blocks(page.extract_text(layout=True) or "")
            headings = [b["text"] for b in blocks if b["kind"] == "heading"]
            if not blocks:
                # An unreadable/blank page cannot establish that a scope continues.
                context.clear()
            explicit = [tuple(path) for _, path in _topic_paths(headings, context)]
            if headings and not explicit:
                context.clear()
            paths = set()
            for path in explicit or [tuple(h for h in context if h)]:
                paths.update(path[:length] for length in range(1, len(path) + 1))
            pages[number] = {"explicit": explicit, "active": paths,
                             "has_headings": bool(headings)}
            page.close()
    return pages


def _path(value):
    return tuple(_normalized_heading(part) for part in value)


def check_scope(path: list[str], basis: str, evidence_pages: list[int],
                anchor_pages: list[int], outline: dict[int, dict]) -> tuple[str, str]:
    expected = _path(path)
    if not expected or not evidence_pages or not anchor_pages:
        return "unknown", "missing_scope_metadata"
    if any(page not in outline for page in evidence_pages + anchor_pages):
        return "unknown", "page_not_extracted"
    if not any(expected in {_path(p) for p in outline[page]["explicit"]}
               for page in anchor_pages):
        return "unknown", "heading_anchor_not_extracted"
    for page in evidence_pages:
        row = outline[page]
        active = {_path(p) for p in row["active"]}
        explicit = {_path(p) for p in row["explicit"]}
        if expected not in active:
            if active and expected[0] not in {p[0] for p in active}:
                return "mismatch", "different_pdf_chapter"
            return "unknown", "scope_not_confirmed"
        if basis == "heading" and expected not in explicit:
            return "mismatch", "heading_not_on_evidence_page"
        if basis == "outline_ancestor" and not any(
                len(p) > len(expected) and p[:len(expected)] == expected for p in explicit):
            return "unknown", "ancestor_not_confirmed_at_page_granularity"
        if basis == "continuation" and row["has_headings"]:
            return "unknown", "continuation_page_has_headings"
        if basis not in {"heading", "outline_ancestor", "continuation", "topic"}:
            return "unknown", "unsupported_scope_basis"
    return "match", "pdf_heading_scope_confirmed"


def build_assessment(candidate: dict, packet: dict, freeze: dict,
                     outline: dict[int, dict], pdf_hash: str) -> dict:
    records = validate_candidate(candidate, freeze)
    verify(packet, EXPORT_MODE)
    if (packet.get("target_kind") != "graph"
            or packet.get("target_content_sha256") != candidate["content_sha256"]
            or packet.get("corpus_freeze_sha256") != freeze["content_sha256"]
            or pdf_hash != freeze["source_sha256"]):
        raise ManualGraphError("source check packet/candidate/PDF binding mismatch")
    exported = {r["record_id"]: r for r in packet["records"]}
    if len(exported) != len(packet["records"]) or set(exported) != set(records):
        raise ManualGraphError("source check packet records differ")
    if any(exported[rid]["record_sha256"] != content_sha256(row)
           for rid, row in records.items()):
        raise ManualGraphError("source check packet record hash mismatch")
    # Packet citations are metadata only; no chunk content is read or exported here.
    citations = {}
    for row in exported.values():
        for item in row.get("evidence", []) + row.get("scope_evidence", []):
            previous = citations.setdefault(item["chunk_id"], item)
            if previous != item:
                raise ManualGraphError("inconsistent packet citation metadata")
    chapters = defaultdict(set)
    for node in candidate["nodes"]:
        if node["type"] == "topic" and node.get("context_path"):
            chapter = node["context_path"][0]
            chapters[node["id"]].add(chapter)
            for cid in node["evidence_chunk_ids"]:
                chapters[cid].add(chapter)
    result = {}
    for rid, row in records.items():
        topic = row if row["type"] == "topic" else next(
            (records[eid] for eid in (row.get("from"), row.get("to"))
             if eid in records and records[eid]["type"] == "topic"), None)
        if row["type"] in {"MENTIONS", "SUPPORTED_BY"} and topic:
            chapters[rid].update(chapters[topic["id"]])
        pages = [citations.get(cid, {}).get("pdf_page") for cid in row["evidence_chunk_ids"]]
        if topic:
            anchors = set(topic.get("heading_chunk_ids", []))
            if row["type"] != "topic":
                anchors &= set(row.get("scope_evidence_chunk_ids", []))
            anchor_pages = [citations.get(cid, {}).get("pdf_page") for cid in sorted(anchors)]
            status, reason = check_scope(topic.get("context_path", []),
                row.get("scope_basis", "topic"), pages, anchor_pages, outline)
        else:
            status, reason = "unknown", "chunk_locator_only_no_semantic_scope"
        result[rid] = {"record_sha256": content_sha256(row),
                       "chapters": sorted(chapters[rid]), "auto_check": status,
                       "auto_check_reason": reason}
    counts = {chapter: sum(chapter in row["chapters"] for row in result.values())
              for chapter in sorted({c for row in result.values() for c in row["chapters"]})}
    return sign({"schema_version": 1, "mode": MODE,
                 "packet_sha256": packet["content_sha256"], "pdf_sha256": pdf_hash,
                 "candidate_sha256": candidate["content_sha256"],
                 "instructions": INSTRUCTIONS, "records": result,
                 "chapter_record_counts": counts,
                 "auto_check_counts": {status: sum(r["auto_check"] == status for r in result.values())
                                       for status in ("match", "mismatch", "unknown")},
                 "release_ready": False})


def main(argv=None):
    parser = argparse.ArgumentParser(description="Kiểm heading PDF local; không duyệt tự động")
    for name in ("workspace", "manifest", "packet", "candidate", "corpus-freeze", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--source-id", required=True)
    args = parser.parse_args(argv)
    workspace = args.workspace.resolve()
    source, pdf = resolve_source(workspace=workspace,
        manifest_path=workspace / args.manifest, source_id=args.source_id)
    if pdf.suffix.lower() != ".pdf":
        raise ManualGraphError("source check requires PDF")
    freeze = load_json(local_path(workspace, args.corpus_freeze))
    if freeze.get("source_sha256") != source["sha256"]:
        raise ManualGraphError("PDF differs from frozen source")
    candidate = load_json(local_path(workspace, args.candidate))
    packet = load_json(local_path(workspace, args.packet))
    validate_candidate(candidate, freeze)
    try:
        outline = pdf_outline(pdf)
    except Exception:
        raise ManualGraphError("local PDF extraction failed") from None
    if file_sha256(pdf) != source["sha256"]:
        raise ManualGraphError("PDF changed during extraction")
    result = build_assessment(candidate, packet, freeze, outline, source["sha256"])
    write_once_atomic(local_path(workspace, args.output), result)
    print(f"records={len(result['records'])} auto_check={result['auto_check_counts']}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ManualGraphError, OSError, ValueError):
        # Never echo PDF extraction exceptions, which can carry source text.
        print("Local source check failed; verify input hashes and paths.", file=sys.stderr)
        raise SystemExit(2) from None
