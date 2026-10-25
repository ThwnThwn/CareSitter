from __future__ import annotations

from copy import deepcopy

from .corpus_freeze import validate_retrieval_corpus_freeze_document
from .errors import ManualGraphError
from .jsonio import content_sha256
from .retrieval_artifacts import sign, verify
from .retrieval_review import _validate_review, _timestamp, _required_text

NODE_TYPES = {"source_revision", "chunk", "topic", "concept", "claim"}
EDGE_TYPES = {"LOCATED_IN", "MENTIONS", "SUPPORTED_BY", "RELATED_TO"}


def build_graph_candidate(chunks: list[dict], corpus_freeze: dict) -> dict:
    """Headings propose topics and evidence links; none are admitted automatically."""
    nodes, edges = {}, {}
    revision = corpus_freeze["source_revision_id"]
    for chunk in chunks:
        cid = chunk["chunk_id"]
        nodes[cid] = {"id": cid, "type": "chunk", "chunk_id": cid, "label": cid,
                      "source_revision_id": revision, "evidence_chunk_ids": [cid]}
        for heading in chunk.get("headings") or []:
            if not heading.strip():
                continue
            tid = "topic:" + content_sha256({"revision": revision, "heading": heading})[:24]
            node = nodes.setdefault(tid, {"id": tid, "type": "topic", "label": heading,
                                    "source_revision_id": revision, "evidence_chunk_ids": []})
            node["evidence_chunk_ids"] = sorted(set(node["evidence_chunk_ids"]) | {cid})
            for kind, src, dst in (("MENTIONS", cid, tid), ("SUPPORTED_BY", tid, cid)):
                eid = "edge:" + content_sha256([kind, src, dst])[:24]
                edges[eid] = {"id": eid, "type": kind, "from": src, "to": dst,
                              "source_revision_id": revision, "evidence_chunk_ids": [cid]}
    candidate = sign({"schema_version": 1, "mode": "retrieval_graph_candidate",
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
    edges = [e for e in candidate["edges"] if e["id"] in approved
             and e["from"] in node_ids and e["to"] in node_ids]
    return sign({"schema_version": 1, "mode": "reviewed_retrieval_graph",
                 "corpus_freeze_sha256": corpus_freeze["content_sha256"],
                 "candidate_sha256": candidate["content_sha256"], "ledger_sha256": ledger["content_sha256"],
                 "nodes": nodes, "edges": edges, "automatic_admissions": 0})
