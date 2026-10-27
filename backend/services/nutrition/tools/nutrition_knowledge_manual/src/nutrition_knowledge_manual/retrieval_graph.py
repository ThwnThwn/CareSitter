from __future__ import annotations

from copy import deepcopy
import re
import unicodedata

from .corpus_freeze import validate_retrieval_corpus_freeze_document
from .errors import ManualGraphError
from .jsonio import content_sha256
from .retrieval_artifacts import sign, verify
from .retrieval_review import _validate_review, _timestamp, _required_text

NODE_TYPES = {"source_revision", "chunk", "topic", "concept", "claim"}
EDGE_TYPES = {"LOCATED_IN", "MENTIONS", "SUPPORTED_BY", "RELATED_TO"}


_GENERIC_HEADINGS = {
    "DAI CUONG", "CO CHE BENH SINH", "CHAN DOAN", "CHE DO DINH DUONG",
    "CHE DO DINH DUONG DIEU TRI", "DINH DUONG DIEU TRI", "DINH DUONG DU PHONG VA DIEU TRI",
    "THUC DON", "THUC DON THAM KHAO", "MUC TIEU",
    "DINH NGHIA", "PHAN LOAI", "NGUYEN TAC DINH DUONG", "LAM SANG", "CAN LAM SANG",
}
_NON_SEMANTIC_HEADINGS = {"THUC DON", "THUC DON THAM KHAO"}
_ROOT_TITLE_MARKERS = {
    "DINH DUONG", "CHE DO", "DANH GIA", "XAY DUNG KHAU PHAN", "TAM QUAN TRONG",
    "1000 NGAY", "GANH NANG", "SU DUNG DON VI", "QUY TRINH", "TO CHUC",
    "PHU LUC", "TIEU CHAY", "UNG THU", "CHUONG",
}
_CONTRIBUTOR = re.compile(r"^(?:GS|PGS|TS|THS|BS|BSCK(?:I{1,2}|1|2)?|CNDD|KTV)[.\s]", re.IGNORECASE)
_HEADING_NUMBER = re.compile(r"^(?:[IVXLCDM]+|\d+(?:\.\d+)*)\.?\s+", re.IGNORECASE)
_ROMAN_HEADING = re.compile(r"^[IVXLCDM]+\.?\s+", re.IGNORECASE)
_ARABIC_HEADING = re.compile(r"^(?:(\d+)\.\s+|(\d+(?:\.\d+)+)\.?\s+)")
_REFERENCE_ENTRY = re.compile(
    r"^\d+\.\s+.*(?:\b(?:19|20)\d{2}\b|et al\.?|và cộng sự|nhà xuất bản|\bNXB\b|journal|https?://|www\.)",
    re.IGNORECASE,
)


def _normalized_heading(value: str) -> str:
    normalized = unicodedata.normalize("NFD", value)
    normalized = "".join(char for char in normalized if unicodedata.category(char) != "Mn")
    return " ".join(normalized.upper().replace("Đ", "D").split())


def _is_reference_section(heading: str) -> bool:
    normalized = _normalized_heading(heading)
    return "TAI LIEU THAM KHAO" in normalized or any(marker in normalized for marker in (
        "NHA XUAT BAN", "TONG GIAM DOC", "TONG BIEN TAP", "PHO TONG BIEN TAP",
        "CHIU TRACH NHIEM XUAT BAN", "LOI NOI DAU", "LOI GIOI THIEU",
        "BAN BIEN SOAN", "MUC LUC", "BO Y TE", "VIEN TRUONG VIEN DINH DUONG", "ISBN",
    ))


def _is_reviewable_heading(heading: str, has_context: bool) -> bool:
    value = " ".join(heading.split())
    normalized = _normalized_heading(value)
    without_number = _HEADING_NUMBER.sub("", normalized).strip()
    words = value.split()
    if not value or _CONTRIBUTOR.match(value) or _REFERENCE_ENTRY.match(value):
        return False
    if (any(marker in without_number for marker in _NON_SEMANTIC_HEADINGS)
            or any(mark in value for mark in ("<", ">", "≤", "≥"))):
        return False
    if re.fullmatch(r"(?:[A-Z]\s+){2,}[A-Z]", normalized):
        return False
    if without_number in _GENERIC_HEADINGS and not has_context:
        return False
    if len(value) > 160:
        return False
    if _HEADING_NUMBER.match(value) and len(words) > 12:
        return False
    if _HEADING_NUMBER.match(value) and value.endswith(":") and len(words) > 6:
        return False
    if _HEADING_NUMBER.match(value) and len(value) > 55 and value.endswith((".", ":")):
        return False
    if len(value) > 105 and any(mark in value for mark in (":", ";", ",")):
        return False
    return True


def _is_generic_heading(heading: str) -> bool:
    normalized = _normalized_heading(heading)
    return _HEADING_NUMBER.sub("", normalized).strip() in _GENERIC_HEADINGS


def _is_trusted_root_heading(heading: str) -> bool:
    normalized = _normalized_heading(heading)
    if normalized.startswith("BENH MAN TINH COPD AIDS"):
        return False
    return any(marker in normalized for marker in _ROOT_TITLE_MARKERS)


def _heading_level(heading: str) -> int:
    """Infer a conservative outline level from the printed heading marker."""
    if _ROMAN_HEADING.match(heading):
        return 1
    match = _ARABIC_HEADING.match(heading)
    if match:
        number = match.group(1) or match.group(2)
        return len(number.split(".")) + 1
    letters = [char for char in heading if char.isalpha()]
    if len(letters) >= 4 and heading == heading.upper():
        return 0
    return 0


def _set_context_heading(context: list[str], level: int, heading: str) -> None:
    """Replace siblings instead of accidentally nesting every heading on a page."""
    match = _ARABIC_HEADING.match(heading)
    if match:
        number = match.group(1) or match.group(2)
        parts = number.split(".")
        for index, ancestor in enumerate(context):
            ancestor_match = _ARABIC_HEADING.match(ancestor)
            if not ancestor_match:
                continue
            ancestor_number = ancestor_match.group(1) or ancestor_match.group(2)
            ancestor_parts = ancestor_number.split(".")
            if parts[:len(ancestor_parts)] != ancestor_parts:
                del context[index:]
                break
    del context[level:]
    while len(context) < level:
        context.append("")
    context.append(heading)


def _topic_paths(headings: list[str], context: list[str]) -> list[tuple[str, list[str]]]:
    """Return contextual topic paths while excluding reference and OCR/list noise."""
    normalized_headings = [" ".join(str(raw).split()) for raw in headings]
    leading_roots: list[str] = []
    while normalized_headings:
        candidate = normalized_headings[0]
        letters = [char for char in candidate if char.isalpha()]
        if (_HEADING_NUMBER.match(candidate) or len(letters) < 4
                or candidate != candidate.upper() or _is_reference_section(candidate)):
            break
        leading_roots.append(normalized_headings.pop(0))
    if leading_roots:
        normalized_headings.insert(0, " ".join(leading_roots))

    result: list[tuple[str, list[str]]] = []
    seen_structured_heading = False
    for heading in normalized_headings:
        if not heading:
            continue
        if (_is_reference_section(heading)
                or any(marker in _normalized_heading(heading) for marker in _NON_SEMANTIC_HEADINGS)):
            context.clear()
            break
        level = _heading_level(heading)
        if level == 0 and not _is_trusted_root_heading(heading):
            continue
        if level == 0 and seen_structured_heading:
            # Unnumbered all-caps strings inside a numbered section are commonly table
            # headers or OCR fragments, not a new chapter boundary.
            continue
        if not context and _is_generic_heading(heading):
            # Keep the root only as identity context so its specific descendants do not
            # collide with identical section names from another chapter.
            _set_context_heading(context, level, heading)
            continue
        if not context and level > 0:
            # A numbered item without a chapter context is commonly a bibliography
            # continuation on the next PDF page. Keep it out rather than inventing a root.
            continue
        if not _is_reviewable_heading(heading, bool(context)):
            continue
        seen_structured_heading = seen_structured_heading or level > 0
        _set_context_heading(context, level, heading)
        result.append((heading, [item for item in context if item]))
    return result


def build_graph_candidate(chunks: list[dict], corpus_freeze: dict) -> dict:
    """Propose explicit outline scopes and contiguous continuations for review."""
    nodes, edges = {}, {}
    revision = corpus_freeze["source_revision_id"]
    context: list[str] = []
    heading_anchors: dict[tuple[str, ...], str] = {}
    previous_page = None
    ordered_chunks = sorted(chunks, key=lambda chunk: (
        chunk.get("pdf_page", 10**9),
        chunk.get("chunk_ordinal_on_page", chunk.get("chunk_ordinal_at_locator", 0)),
        chunk["chunk_id"],
    ))
    for chunk in ordered_chunks:
        cid = chunk["chunk_id"]
        page = chunk.get("pdf_page")
        if (previous_page is None or not isinstance(page, int)
                or page not in (previous_page, previous_page + 1)):
            # Missing/excluded pages can contain a chapter boundary. Do not bridge them.
            context.clear()
            heading_anchors.clear()
        previous_page = page if isinstance(page, int) else None
        nodes[cid] = {"id": cid, "type": "chunk", "chunk_id": cid, "label": cid,
                      "source_revision_id": revision, "evidence_chunk_ids": [cid]}
        headings = chunk.get("headings") or []
        explicit_paths = _topic_paths(headings, context)
        scopes: dict[tuple[str, ...], str] = {}
        for _, topic_path in explicit_paths:
            heading_anchors[tuple(topic_path)] = cid
            for length in range(1, len(topic_path) + 1):
                scopes.setdefault(tuple(topic_path[:length]), "outline_ancestor")
            scopes[tuple(topic_path)] = "heading"
        if not headings and context:
            topic_path = tuple(item for item in context if item)
            scopes = {topic_path[:length]: "continuation" for length in range(1, len(topic_path) + 1)}
        elif headings and not explicit_paths:
            # An unrecognized heading is not evidence that the next page continues this scope.
            context.clear()
        for path, basis in scopes.items():
            heading, topic_path = path[-1], list(path)
            anchor = heading_anchors.get(path)
            if anchor is None or not _is_reviewable_heading(heading, len(path) > 1):
                continue
            tid = "topic:" + content_sha256({"revision": revision, "topic_path": topic_path})[:24]
            label = " > ".join(topic_path)
            node = nodes.setdefault(tid, {"id": tid, "type": "topic", "label": label,
                                    "heading": heading, "context_path": topic_path,
                                    "source_revision_id": revision, "evidence_chunk_ids": [],
                                    "heading_chunk_ids": []})
            node["evidence_chunk_ids"] = sorted(set(node["evidence_chunk_ids"]) | {cid})
            node["heading_chunk_ids"] = sorted(set(node["heading_chunk_ids"]) | {anchor})
            for kind, src, dst in (("MENTIONS", cid, tid), ("SUPPORTED_BY", tid, cid)):
                eid = "edge:" + content_sha256([kind, src, dst])[:24]
                edges[eid] = {"id": eid, "type": kind, "from": src, "to": dst,
                              "source_revision_id": revision, "evidence_chunk_ids": [cid],
                              "scope_basis": basis, "scope_evidence_chunk_ids": sorted({cid, anchor})}
    candidate = sign({"schema_version": 1, "mode": "retrieval_graph_candidate",
                      "builder": "contiguous_outline_scopes_v2",
                      "corpus_freeze_sha256": corpus_freeze["content_sha256"],
                      "automatic_admissions": 0,
                      "nodes": sorted(nodes.values(), key=lambda n: n["id"]),
                      "edges": sorted(edges.values(), key=lambda e: e["id"])})
    validate_candidate(candidate, corpus_freeze)
    return candidate


def validate_candidate(candidate: dict, corpus_freeze: dict) -> dict[str, dict]:
    validate_retrieval_corpus_freeze_document(corpus_freeze)
    verify(candidate, "retrieval_graph_candidate")
    if candidate.get("corpus_freeze_sha256") != corpus_freeze["content_sha256"] or candidate.get("automatic_admissions") != 0:
        raise ManualGraphError("graph corpus mismatch or automatic admissions")
    eligible = {c["chunk_id"] for c in corpus_freeze["eligible_chunk_identities"]}
    records, nodes = {}, {}
    for name, allowed in (("nodes", NODE_TYPES), ("edges", EDGE_TYPES)):
        rows = candidate.get(name)
        if not isinstance(rows, list) or len(rows) > 20000:
            raise ManualGraphError("graph exceeds record bounds")
        for row in rows:
            if not isinstance(row, dict):
                raise ManualGraphError("graph record must be an object")
            rid = row.get("id")
            evidence = row.get("evidence_chunk_ids")
            if (not isinstance(rid, str) or not rid or rid in records or row.get("type") not in allowed
                    or row.get("source_revision_id") != corpus_freeze["source_revision_id"]
                    or not isinstance(evidence, list) or not evidence
                    or any(not isinstance(cid, str) for cid in evidence)
                    or len(set(evidence)) != len(evidence) or set(evidence) - eligible):
                raise ManualGraphError("graph record lacks unique identity or eligible provenance")
            records[rid] = row
            if name == "nodes":
                nodes[rid] = row
                if row["type"] == "chunk" and (row.get("chunk_id") not in eligible or row["evidence_chunk_ids"] != [row.get("chunk_id")]):
                    raise ManualGraphError("graph chunk node has invalid evidence")
                if candidate.get("builder") == "contiguous_outline_scopes_v2" and row["type"] == "topic":
                    anchors = row.get("heading_chunk_ids")
                    if (not isinstance(anchors, list) or not anchors
                            or any(not isinstance(cid, str) for cid in anchors)
                            or len(set(anchors)) != len(anchors) or set(anchors) - set(evidence)):
                        raise ManualGraphError("graph topic lacks eligible heading anchors")
            elif row.get("from") not in nodes or row.get("to") not in nodes:
                raise ManualGraphError("graph contains dangling endpoints")
            else:
                source, target = nodes[row["from"]], nodes[row["to"]]
                semantic = {"topic", "concept", "claim"}
                allowed_direction = {
                    "LOCATED_IN": ({"chunk"}, {"source_revision", "topic"}),
                    "MENTIONS": ({"chunk"}, {"topic", "concept"}),
                    "SUPPORTED_BY": (semantic, {"chunk"}),
                    "RELATED_TO": (semantic, semantic),
                }[row["type"]]
                if source["type"] not in allowed_direction[0] or target["type"] not in allowed_direction[1]:
                    raise ManualGraphError("graph edge direction violates the ontology")
                for endpoint in (source, target):
                    if endpoint["type"] == "chunk" and endpoint["chunk_id"] not in evidence:
                        raise ManualGraphError("graph edge does not cite its chunk endpoint")
                if candidate.get("builder") == "contiguous_outline_scopes_v2":
                    anchors = row.get("scope_evidence_chunk_ids")
                    topic = source if source["type"] == "topic" else target
                    heading_ids = set(topic.get("heading_chunk_ids", []))
                    if (row.get("scope_basis") not in {"heading", "outline_ancestor", "continuation"}
                            or not isinstance(anchors, list) or not anchors
                            or any(not isinstance(cid, str) for cid in anchors)
                            or len(set(anchors)) != len(anchors)
                            or set(evidence) - set(anchors) or set(anchors) - (heading_ids | set(evidence))
                            or not set(anchors) & heading_ids):
                        raise ManualGraphError("graph outline edge lacks matching heading evidence")
    chunk_ids = [n["chunk_id"] for n in nodes.values() if n["type"] == "chunk"]
    if len(chunk_ids) != len(set(chunk_ids)):
        raise ManualGraphError("graph repeats a chunk node")
    return records


def empty_graph_review(candidate: dict, corpus_freeze: dict) -> dict:
    records = validate_candidate(candidate, corpus_freeze)
    return sign({"schema_version": 1, "mode": "retrieval_graph_review",
                 "candidate_sha256": candidate["content_sha256"],
                 "records": {rid: {"record_sha256": content_sha256(row), "source_review": None,
                                    "clinical_review": None} for rid, row in records.items()}})


def validate_graph_review(candidate: dict, corpus_freeze: dict, ledger: dict) -> dict:
    records = validate_candidate(candidate, corpus_freeze)
    verify(ledger, "retrieval_graph_review")
    if ledger.get("candidate_sha256") != candidate["content_sha256"] or set(ledger.get("records", {})) != set(records):
        raise ManualGraphError("graph review is stale or incomplete")
    for rid, record in records.items():
        entry = ledger["records"][rid]
        if entry.get("record_sha256") != content_sha256(record):
            raise ManualGraphError("graph record changed after review")
        _validate_review(entry.get("source_review"), {"data_steward"})
        _validate_review(entry.get("clinical_review"), {"dietitian", "physician"})
    return records


def record_graph_review(candidate: dict, corpus_freeze: dict, ledger: dict, record_id: str,
                        decision: str, reviewer_id: str, reviewer_role: str, comment: str) -> dict:
    records = validate_graph_review(candidate, corpus_freeze, ledger)
    if record_id not in records or decision not in {"approved", "rejected"}:
        raise ManualGraphError("invalid graph review target or decision")
    slot = {"data_steward": "source_review", "dietitian": "clinical_review", "physician": "clinical_review"}.get(reviewer_role)
    if slot is None:
        raise ManualGraphError("invalid graph reviewer role")
    result = deepcopy(ledger)
    result["records"][record_id][slot] = {"decision": decision, "reviewer_role": reviewer_role,
        "reviewer_id": _required_text(reviewer_id, "reviewer_id"), "comment": _required_text(comment, "comment"),
        "reviewed_at_utc": _timestamp(None)}
    return sign(result)


def materialize_graph(candidate: dict, corpus_freeze: dict, ledger: dict) -> dict:
    validate_graph_review(candidate, corpus_freeze, ledger)
    approved = {rid for rid, entry in ledger["records"].items()
                if all((entry.get(slot) or {}).get("decision") == "approved"
                       for slot in ("source_review", "clinical_review"))}
    nodes = [n for n in candidate["nodes"] if n["id"] in approved]
    node_ids = {n["id"] for n in nodes}
    approved_chunks = {n["chunk_id"] for n in nodes if n["type"] == "chunk"}
    edges = [e for e in candidate["edges"] if e["id"] in approved
             and e["from"] in node_ids and e["to"] in node_ids
             and set(e.get("scope_evidence_chunk_ids", [])) <= approved_chunks]
    return sign({"schema_version": 1, "mode": "reviewed_retrieval_graph",
                 "corpus_freeze_sha256": corpus_freeze["content_sha256"],
                 "candidate_sha256": candidate["content_sha256"], "ledger_sha256": ledger["content_sha256"],
                 "nodes": nodes, "edges": edges, "automatic_admissions": 0})
