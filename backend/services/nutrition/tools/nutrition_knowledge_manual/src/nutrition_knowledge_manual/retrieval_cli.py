from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any, Callable

from .corpus_freeze import freeze_retrieval_corpus
from .jsonio import load_json, write_json
from .retrieval_eval import load_retrieval_chunks, run_retrieval_eval, validate_retrieval_eval
from .retrieval_holdout import seal_independent_holdout
from .retrieval_pipeline_cli import dispatch_pipeline_command, register_pipeline_commands
from .retrieval_review import (
    build_retrieval_review_packet,
    empty_retrieval_review,
    record_retrieval_case_review,
    retrieval_review_status,
)


Handler = Callable[[argparse.Namespace, Path], dict[str, Any]]


def register_retrieval_commands(commands: argparse._SubParsersAction) -> None:
    register_pipeline_commands(commands)
    validate = commands.add_parser("validate-retrieval-eval")
    validate.add_argument("--cases", type=Path, required=True)
    validate.add_argument("--chunks", type=Path, required=True)
    validate.add_argument("--corpus-freeze", type=Path, required=True)

    run = commands.add_parser("run-retrieval-eval")
    run.add_argument("--cases", type=Path, required=True)
    run.add_argument("--chunks", type=Path, required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--top-k", type=int, default=5)
    run.add_argument("--corpus-freeze", type=Path, required=True)

    freeze = commands.add_parser("freeze-retrieval-corpus")
    freeze.add_argument("--manifest", type=Path, required=True)
    freeze.add_argument("--source-id", required=True)
    freeze.add_argument("--chunks", type=Path, required=True)
    freeze.add_argument("--report", type=Path, required=True)
    freeze.add_argument("--output", type=Path, required=True)

    init_review = commands.add_parser("init-retrieval-review")
    init_review.add_argument("--cases", type=Path, required=True)
    init_review.add_argument("--corpus-freeze", type=Path, required=True)
    init_review.add_argument("--output", type=Path, required=True)

    review_case = commands.add_parser("review-retrieval-case")
    review_case.add_argument("--cases", type=Path, required=True)
    review_case.add_argument("--corpus-freeze", type=Path, required=True)
    review_case.add_argument("--ledger", type=Path, required=True)
    review_case.add_argument("--case-id", required=True)
    review_case.add_argument("--decision", choices=["approved", "rejected"], required=True)
    review_case.add_argument("--reviewer-id", required=True)
    review_case.add_argument(
        "--reviewer-role", choices=["data_steward", "dietitian", "physician"], required=True
    )
    review_case.add_argument("--comment", required=True)

    status = commands.add_parser("retrieval-review-status")
    status.add_argument("--cases", type=Path, required=True)
    status.add_argument("--corpus-freeze", type=Path, required=True)
    status.add_argument("--ledger", type=Path, required=True)

    packet = commands.add_parser("build-retrieval-review-packet")
    packet.add_argument("--cases", type=Path, required=True)
    packet.add_argument("--corpus-freeze", type=Path, required=True)
    packet.add_argument("--chunks", type=Path, required=True)
    packet.add_argument("--output", type=Path, required=True)
    packet.add_argument("--preview-characters", type=int, default=600)

    holdout = commands.add_parser("seal-independent-retrieval-holdout")
    holdout.add_argument("--submission", type=Path, required=True)
    holdout.add_argument("--corpus-freeze", type=Path, required=True)
    holdout.add_argument("--visible-evaluation", type=Path, action="append", required=True)
    holdout.add_argument("--output", type=Path, required=True)


def dispatch_retrieval_command(
    args: argparse.Namespace, workspace: Path
) -> tuple[bool, dict[str, Any] | None]:
    handler = _HANDLERS.get(args.command)
    return dispatch_pipeline_command(args, workspace) if handler is None else (True, handler(args, workspace))


def _validate(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    chunks = load_retrieval_chunks(args.chunks)
    return validate_retrieval_eval(
        cases=load_json(args.cases),
        chunks_path=args.chunks,
        chunks=chunks,
        corpus_freeze=load_json(args.corpus_freeze),
    )


def _run(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    result = run_retrieval_eval(
        cases=load_json(args.cases),
        chunks_path=args.chunks,
        top_k=args.top_k,
        corpus_freeze=load_json(args.corpus_freeze),
    )
    write_json(args.output, result)
    return {
        "status": "release_ready" if result["release_ready"] else "evaluation_only",
        "recall_at_k": result["metrics"]["recall_at_k"],
        "mrr": result["metrics"]["mrr"],
        "abstention_accuracy": result["metrics"]["abstention_accuracy"],
        "citation_integrity": result["metrics"]["citation_integrity"],
        "gate_failures": result["gate_failures"],
        "output": str(args.output.resolve()),
    }


def _freeze(args: argparse.Namespace, workspace: Path) -> dict[str, Any]:
    result = freeze_retrieval_corpus(
        workspace=workspace,
        manifest_path=args.manifest,
        source_id=args.source_id,
        chunks_path=args.chunks,
        report_path=args.report,
    )
    write_json(args.output, result)
    return {
        "status": "retrieval_corpus_frozen",
        "content_sha256": result["content_sha256"],
        "eligible_chunk_count": result["eligible_chunk_count"],
        "excluded_chunk_count": result["excluded_chunk_count"],
        "output": str(args.output.resolve()),
    }


def _init_review(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    result = empty_retrieval_review(
        cases=load_json(args.cases), corpus_freeze=load_json(args.corpus_freeze)
    )
    write_json(args.output, result)
    return {
        "status": "retrieval_review_initialized",
        "case_count": len(result["decisions"]),
        "ledger_content_sha256": result["content_sha256"],
        "output": str(args.output.resolve()),
    }


def _review_case(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    result = record_retrieval_case_review(
        cases=load_json(args.cases),
        corpus_freeze=load_json(args.corpus_freeze),
        ledger=load_json(args.ledger),
        case_id=args.case_id,
        decision=args.decision,
        reviewer_id=args.reviewer_id,
        reviewer_role=args.reviewer_role,
        comment=args.comment,
    )
    write_json(args.ledger, result)
    return {
        "status": "retrieval_case_review_recorded",
        "case_id": args.case_id,
        "reviewer_role": args.reviewer_role,
        "decision": args.decision,
        "ledger_content_sha256": result["content_sha256"],
    }


def _review_status(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    return retrieval_review_status(
        cases=load_json(args.cases),
        corpus_freeze=load_json(args.corpus_freeze),
        ledger=load_json(args.ledger),
    )


def _review_packet(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    result = build_retrieval_review_packet(
        cases=load_json(args.cases),
        corpus_freeze=load_json(args.corpus_freeze),
        chunks_path=args.chunks,
        preview_characters=args.preview_characters,
    )
    write_json(args.output, result)
    return {
        "status": "retrieval_review_packet_created",
        "case_count": result["case_count"],
        "content_sha256": result["content_sha256"],
        "output": str(args.output.resolve()),
    }


def _seal_holdout(args: argparse.Namespace, _: Path) -> dict[str, Any]:
    result = seal_independent_holdout(
        submission=load_json(args.submission),
        corpus_freeze=load_json(args.corpus_freeze),
        visible_evaluations=[load_json(path) for path in args.visible_evaluation],
    )
    write_json(args.output, result)
    return {
        "status": result["consumption_state"],
        "case_count": result["case_count"],
        "content_sha256": result["content_sha256"],
        "release_ready": result["release_ready"],
        "output": str(args.output.resolve()),
    }


_HANDLERS: dict[str, Handler] = {
    "validate-retrieval-eval": _validate,
    "run-retrieval-eval": _run,
    "freeze-retrieval-corpus": _freeze,
    "init-retrieval-review": _init_review,
    "review-retrieval-case": _review_case,
    "retrieval-review-status": _review_status,
    "build-retrieval-review-packet": _review_packet,
    "seal-independent-retrieval-holdout": _seal_holdout,
}
