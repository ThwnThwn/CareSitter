"""Create a human review sheet and turn completed rows into an M4 decision batch.

The sheet is deliberately editable. Packet IDs and hashes are checked again before
building a batch, while the existing importer remains the authority for ledger state.
"""

from __future__ import annotations

import argparse
import csv
from copy import deepcopy
from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend/services/nutrition/tools/nutrition_knowledge_manual/src"))

from nutrition_knowledge_manual.errors import ManualGraphError  # noqa: E402
from nutrition_knowledge_manual.jsonio import file_sha256, load_json  # noqa: E402
from nutrition_knowledge_manual.retrieval_artifacts import (  # noqa: E402
    local_path,
    sign,
    verify,
    write_once_atomic,
)
from nutrition_knowledge_manual.review_batch import EXPORT_MODE  # noqa: E402
from nutrition_knowledge_manual.graph_source_review import MODE, INSTRUCTIONS  # noqa: E402

ROLES = ("data_steward", "dietitian", "physician")
FIELDS = (
    "packet_sha256", "reviewer_role", "record_id", "record_sha256",
    "record_type", "question_or_label", "from_node", "to_node", "scope_basis",
    "scope_pages", "citation_pages", "owner_approval",
    "source_review", "clinical_review", "decision", "comment",
)
SCOPE_FIELDS = ("chapters", "auto_check", "auto_check_reason", "instructions", "reviewer_id")


def scope_records(packet, records, assessment, chapters):
    if assessment is None:
        if chapters:
            raise ManualGraphError("chapter selection requires --assessment")
        return records
    verify(assessment, MODE)
    if (assessment.get("packet_sha256") != packet["content_sha256"]
            or assessment.get("candidate_sha256") != packet["target_content_sha256"]
            or set(assessment.get("records", {})) != set(records)):
        raise ManualGraphError("assessment belongs to another packet")
    for rid, record in records.items():
        if assessment["records"][rid].get("record_sha256") != record["record_sha256"]:
            raise ManualGraphError("assessment record hash differs")
    known = set(assessment["chapter_record_counts"])
    if chapters and (set(chapters) - known or len(set(chapters)) != len(chapters)):
        raise ManualGraphError("unknown or duplicate chapter selection")
    selected = {rid: record for rid, record in records.items()
                if not chapters or set(assessment["records"][rid]["chapters"]) & set(chapters)}
    if not selected:
        raise ManualGraphError("chapter scope contains no records")
    return selected


def scoped_row(packet, role, rid, record, graph, labels, assessment):
    row = sheet_row(packet, role, rid, record, graph, labels)
    if assessment is not None:
        metadata = assessment["records"][rid]
        row.update(chapters=excel_safe("; ".join(metadata["chapters"])),
                   auto_check=metadata["auto_check"],
                   auto_check_reason=metadata["auto_check_reason"],
                   instructions=INSTRUCTIONS, reviewer_id="")
    return row


def packet_records(packet: dict) -> tuple[str, dict[str, dict]]:
    verify(packet, EXPORT_MODE)
    kind = packet.get("target_kind")
    if kind not in {"case", "graph"}:
        raise ManualGraphError("packet target_kind must be case or graph")
    key = "case_id" if kind == "case" else "record_id"
    records = packet.get("records")
    if not isinstance(records, list) or not records:
        raise ManualGraphError("packet has no review records")
    by_id = {}
    for record in records:
        record_id = record.get(key)
        if not isinstance(record_id, str) or not record_id or record_id in by_id:
            raise ManualGraphError("packet has missing or duplicate record IDs")
        by_id[record_id] = record
    template = packet.get("decision_batch_template")
    if not isinstance(template, dict) or template.get("target_kind") != kind:
        raise ManualGraphError("packet has no matching decision template")
    for field in ("target_content_sha256", "corpus_freeze_sha256", "ledger_content_sha256"):
        if template.get(field) != packet.get(field):
            raise ManualGraphError(f"packet template does not match {field}")
    if {row.get(key): row.get("record_sha256") for row in template.get("decisions", [])} != {
            record_id: record["record_sha256"] for record_id, record in by_id.items()}:
        raise ManualGraphError("packet template does not match review records")
    return key, by_id


def citation_pages(record: dict, kind: str) -> str:
    citations = record.get("candidate_citations") if kind == "case" else record.get("evidence")
    citations = citations or []
    return "; ".join(
        f"{item.get('chunk_id')} | PDF {item.get('pdf_page')} | in {item.get('printed_page')}"
        for item in citations
    )


def excel_safe(value: object) -> str:
    text = str(value) if value is not None else ""
    return "'" + text if text.lstrip().startswith(("=", "+", "-", "@")) else text


def graph_records(packet: dict, candidate: dict | None) -> tuple[dict, dict]:
    if packet["target_kind"] == "case":
        return {}, {}
    if candidate is None:
        raise ManualGraphError("graph review requires --candidate")
    verify(candidate, "retrieval_graph_candidate")
    if candidate["content_sha256"] != packet["target_content_sha256"]:
        raise ManualGraphError("graph candidate does not match review packet")
    rows = candidate["nodes"] + candidate["edges"]
    by_id = {row["id"]: row for row in rows}
    if len(by_id) != len(rows):
        raise ManualGraphError("graph candidate contains duplicate IDs")
    labels = {row["id"]: row.get("label") or row.get("heading") or row["id"]
              for row in candidate["nodes"]}
    return by_id, labels


def sheet_row(packet: dict, role: str, record_id: str, record: dict,
              graph: dict, labels: dict) -> dict[str, str]:
    relation = graph.get(record_id, {})
    from_id, to_id = relation.get("from"), relation.get("to")
    return {
        "packet_sha256": packet["content_sha256"],
        "reviewer_role": role,
        "record_id": record_id,
        "record_sha256": record["record_sha256"],
        "record_type": record.get("record_type", "case"),
        "question_or_label": excel_safe(record.get("question") or record.get("label")
                                        or record.get("heading")
                                        or (f"{labels.get(from_id, from_id)} → {labels.get(to_id, to_id)}"
                                            if from_id and to_id else "")),
        "from_node": from_id or "",
        "to_node": to_id or "",
        "scope_basis": record.get("scope_basis") or "",
        "scope_pages": excel_safe("; ".join(
            f"{item.get('chunk_id')} | PDF {item.get('pdf_page')} | in {item.get('printed_page')}"
            for item in (record.get("scope_evidence") or []))),
        "citation_pages": excel_safe(citation_pages(record, packet["target_kind"])),
        "owner_approval": excel_safe(record.get("owner_approval")),
        "source_review": excel_safe(record.get("source_locator_review") or record.get("source_review")),
        "clinical_review": excel_safe(record.get("clinical_relevance_review") or record.get("clinical_review")),
        "decision": "",
        "comment": "",
    }


def export_sheet(packet: dict, candidate: dict | None, path: Path, role: str,
                 assessment: dict | None = None, chapters: list[str] | None = None) -> int:
    if role not in ROLES:
        raise ManualGraphError("invalid reviewer role")
    key, records = packet_records(packet)
    graph, labels = graph_records(packet, candidate)
    if graph and set(records) != set(graph):
        raise ManualGraphError("graph packet and candidate record IDs differ")
    records = scope_records(packet, records, assessment, chapters)
    if path.exists():
        raise ManualGraphError("review sheet exists; choose a new path")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS + (SCOPE_FIELDS if assessment else ()))
        writer.writeheader()
        for record_id, record in records.items():
            writer.writerow(scoped_row(packet, role, record_id, record, graph, labels, assessment))
    return len(records)


def build_batch(packet: dict, candidate: dict | None, sheet: Path,
                reviewer_id: str, reviewer_role: str, output: Path,
                assessment: dict | None = None, chapters: list[str] | None = None) -> int:
    key, records = packet_records(packet)
    graph, labels = graph_records(packet, candidate)
    if reviewer_role not in ROLES:
        raise ManualGraphError("invalid reviewer role")
    records = scope_records(packet, records, assessment, chapters)
    if not reviewer_id.strip():
        raise ManualGraphError("reviewer_id is required")
    with sheet.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        fields = FIELDS + (SCOPE_FIELDS if assessment else ())
        if tuple(reader.fieldnames or ()) != fields:
            raise ManualGraphError("review sheet columns have changed")
        rows = list(reader)
    if len(rows) != len(records):
        raise ManualGraphError("review sheet must retain every packet record")
    by_id = {}
    roles = set()
    for row in rows:
        if None in row or any(row.get(field) is None for field in fields):
            raise ManualGraphError("review sheet contains a malformed CSV row")
        record_id = row["record_id"]
        record = records.get(record_id)
        if record is None or record_id in by_id:
            raise ManualGraphError(f"unknown or duplicate record: {record_id}")
        roles.add(row["reviewer_role"])
        expected = scoped_row(packet, reviewer_role, record_id, record, graph, labels, assessment)
        immutable = [field for field in fields if field not in {"decision", "comment", "reviewer_id"}]
        if any(row[field] != expected[field] for field in immutable):
            raise ManualGraphError(f"stale or edited evidence columns: {record_id}")
        decision = row["decision"].strip().lower()
        comment = row["comment"].strip()
        if decision not in {"", "approved", "rejected"} or bool(decision) != bool(comment):
            raise ManualGraphError(f"decision and comment must both be complete: {record_id}")
        if assessment and ((decision and row["reviewer_id"].strip() != reviewer_id.strip())
                           or (not decision and row["reviewer_id"].strip())):
            raise ManualGraphError(f"reviewer_id must match completed rows: {record_id}")
        by_id[record_id] = (decision, comment)
    if roles != {reviewer_role}:
        raise ManualGraphError("review sheet role differs from the attested reviewer role")
    decisions = [
        {key: record_id, "record_sha256": record["record_sha256"],
         "decision": by_id[record_id][0], "comment": by_id[record_id][1]}
        for record_id, record in records.items() if by_id[record_id][0]
    ]
    if not decisions:
        raise ManualGraphError("review sheet has no completed decisions")
    batch = deepcopy(packet["decision_batch_template"])
    batch["reviewer_id"] = reviewer_id.strip()
    batch["reviewer_role"] = reviewer_role
    batch["decision_source"] = {
        "type": "completed_review_file",
        "reference": f"review-sheet-sha256:{file_sha256(sheet)}",
        "attested": True,
    }
    batch["decisions"] = decisions
    write_once_atomic(output, sign(batch))
    return len(decisions)


def main() -> int:
    parser = argparse.ArgumentParser(description="Nutrition M4 human review sheet")
    parser.add_argument("--workspace", type=Path, default=REPO)
    parser.add_argument("--packet", type=Path, required=True)
    parser.add_argument("--candidate", type=Path,
                        help="Required for graph packets; shows edge endpoints and anchor pages")
    parser.add_argument("--assessment", type=Path, help="Local PDF heading check artifact")
    parser.add_argument("--chapter", action="append", help="Exact top-level heading; repeat for a list")
    parser.add_argument("--scope-config", type=Path, help="Editable proposal JSON with chapters list")
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export")
    export.add_argument("--reviewer-role", choices=ROLES, required=True)
    export.add_argument("--sheet", type=Path, required=True)
    build = commands.add_parser("build")
    build.add_argument("--sheet", type=Path, required=True)
    build.add_argument("--reviewer-id", required=True)
    build.add_argument("--reviewer-role", choices=ROLES, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--attest", action="store_true", required=True,
                       help="Reviewer confirms the filled decisions are their own")
    from nutrition_knowledge_manual.review_policy import add_argument, check
    add_argument(parser)
    args = parser.parse_args()
    check(args.review_policy, role=args.reviewer_role)
    workspace = args.workspace.resolve()
    packet = load_json(local_path(workspace, args.packet))
    check(args.review_policy, packet)
    candidate = load_json(local_path(workspace, args.candidate)) if args.candidate else None
    assessment = load_json(local_path(workspace, args.assessment)) if args.assessment else None
    chapters = args.chapter
    if args.scope_config:
        if chapters:
            raise ManualGraphError("use --chapter or --scope-config, not both")
        config = load_json(workspace / args.scope_config)
        chapters = config.get("chapters")
        if not isinstance(chapters, list) or not chapters or any(not isinstance(c, str) for c in chapters):
            raise ManualGraphError("scope config requires a non-empty chapters list")
    if args.command == "export":
        sheet = local_path(workspace, args.sheet)
        count = export_sheet(packet, candidate, sheet, args.reviewer_role, assessment, chapters)
        print(f"Created {count}-record review sheet: {sheet}")
    else:
        sheet = local_path(workspace, args.sheet)
        output = local_path(workspace, args.output)
        count = build_batch(packet, candidate, sheet, args.reviewer_id, args.reviewer_role, output,
                            assessment, chapters)
        print(f"Created {count}-decision batch: {output}")
        print("Run nutrition-review-import.ps1 for dry-run, then apply to a new ledger revision.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ManualGraphError, OSError, ValueError) as error:
        print(f"Review sheet error: {error}", file=sys.stderr)
        raise SystemExit(2) from None
