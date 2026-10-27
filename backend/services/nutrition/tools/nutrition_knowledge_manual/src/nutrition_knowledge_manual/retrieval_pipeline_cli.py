"""CLI adapters for M4.3–M4.6; domain gates live in the retrieval modules."""
from __future__ import annotations

import argparse
from pathlib import Path

from .corpus_freeze import validate_retrieval_corpus_binding
from .catalog_evidence import build_catalog_evidence_packet
from .embedding_index import build_embedding_index
from .graph_diagnostics import inspect_graph
from .errors import ManualGraphError
from .jsonio import content_sha256, load_json
from .ollama_encoder import OllamaEncoder
from .retrieval_artifacts import code_identity, local_path, write_once, write_once_atomic
from .retrieval_benchmark import benchmark
from .retrieval_eval import load_retrieval_chunks
from .retrieval_graph import build_graph_candidate, empty_graph_review, materialize_graph, record_graph_review
from .retrieval_release import (consume_holdout, freeze_benchmark, release_manifest, seal_for_benchmark)
from .released_search import ReleasedEvidenceSearch, require_internal_search_release
from .review_batch import (apply_review_import, build_case_review_export, build_graph_review_export,
                           plan_review_import)
from .retrieval_suite import create_suite
from .retrieval_review_draft import build_visible_review_draft
from .visible_registry import build_repair_inventory, build_visible_registry


def register_pipeline_commands(commands: argparse._SubParsersAction) -> None:
    for name in _HANDLERS:
        parser = commands.add_parser(name)
        if name in {"export-retrieval-case-review", "export-retrieval-graph-review"}:
            parser.add_argument("--output", type=Path, required=True)
            parser.add_argument("--corpus-freeze", type=Path, required=True)
            parser.add_argument("--ledger", type=Path, required=True)
            parser.add_argument("--chunks", type=Path, required=True)
            if name == "export-retrieval-case-review":
                parser.add_argument("--cases", type=Path, required=True)
                parser.add_argument("--owner-approval", type=Path)
            else:
                parser.add_argument("--graph-candidate", type=Path, required=True)
            continue
        if name in {"plan-retrieval-review-import", "apply-retrieval-review-import"}:
            parser.add_argument("--output", type=Path, required=True)
            parser.add_argument("--target-kind", choices=["case", "graph"], required=True)
            parser.add_argument("--target", type=Path, required=True)
            parser.add_argument("--corpus-freeze", type=Path, required=True)
            parser.add_argument("--ledger", type=Path, required=True)
            parser.add_argument("--batch", type=Path, required=True)
            if name == "apply-retrieval-review-import":
                parser.add_argument("--plan", type=Path, required=True)
            continue
        if name == "search-released-evidence":
            parser.add_argument("--release-manifest", type=Path, required=True)
            parser.add_argument("--question", required=True)
            parser.add_argument("--top-k", type=int, default=5)
            parser.add_argument("--source-revision-id")
            parser.add_argument("--corpus-freeze", type=Path, required=True)
            parser.add_argument("--chunks", type=Path, required=True)
            parser.add_argument("--config", type=Path, required=True)
            for field in ("index", "graph-candidate", "graph-ledger", "graph"):
                parser.add_argument("--" + field, type=Path)
            for field in ("cases", "visible-report", "review-ledger", "benchmark-freeze",
                          "submission", "holdout-ledger", "holdout-report"):
                parser.add_argument("--" + field, type=Path, required=True)
            parser.add_argument("--endpoint", default="http://127.0.0.1:11434")
            continue
        if name in {"build-visible-registry", "build-repair-inventory"}:
            parser.add_argument("--output", type=Path, required=True)
            if name == "build-repair-inventory":
                parser.add_argument("--base-inventory", type=Path, required=True)
                parser.add_argument("--registry", type=Path, required=True)
            continue
        parser.add_argument("--corpus-freeze", type=Path, required=True)
        parser.add_argument("--output", type=Path, required=True)
        if name == "seal-retrieval-benchmark-holdout":
            parser.add_argument("--submission", type=Path, required=True)
            parser.add_argument("--benchmark-freeze", type=Path, required=True)
            parser.add_argument("--visible-evaluation", type=Path, action="append", required=True)
            continue
        parser.add_argument("--chunks", type=Path, required=True)
        if name == "build-retrieval-review-draft":
            parser.add_argument("--cases", type=Path, required=True)
            continue
        if name == "build-catalog-evidence-packet":
            parser.add_argument("--claims", type=Path, required=True)
            parser.add_argument("--strategy", choices=["keyword", "vector", "hybrid", "graph"], default="keyword")
            parser.add_argument("--endpoint", default="http://127.0.0.1:11434")
            parser.add_argument("--config", type=Path, required=True)
            for field in ("index", "graph-candidate", "graph-ledger", "graph"):
                parser.add_argument("--" + field, type=Path)
            continue
        if name in {"review-retrieval-graph-record", "materialize-retrieval-graph", "inspect-retrieval-graph"}:
            parser.add_argument("--graph-candidate", type=Path, required=True)
            if name != "inspect-retrieval-graph":
                parser.add_argument("--graph-ledger", type=Path, required=True)
            if name == "review-retrieval-graph-record":
                for field in ("record-id", "reviewer-id", "comment"):
                    parser.add_argument("--" + field, required=True)
                parser.add_argument("--reviewer-role", choices=["data_steward", "dietitian", "physician"], required=True)
                parser.add_argument("--decision", choices=["approved", "rejected"], required=True)
            continue
        if name == "build-retrieval-graph-candidate":
            parser.add_argument("--ledger-output", type=Path, required=True)
            continue
        parser.add_argument("--endpoint", default="http://127.0.0.1:11434")
        if name == "build-retrieval-embedding-index":
            parser.add_argument("--model-digest", required=True)
            parser.add_argument("--cache", type=Path, required=True)
            continue
        parser.add_argument("--config", type=Path, required=True)
        for field in ("index", "graph-candidate", "graph-ledger", "graph"):
            parser.add_argument("--" + field, type=Path)
        if name == "run-retrieval-holdout":
            for field in ("submission", "holdout-marker", "benchmark-freeze", "review-ledger"):
                parser.add_argument("--" + field, type=Path, required=True)
            continue
        parser.add_argument("--cases", type=Path, required=True)
        if name != "run-retrieval-benchmark":
            parser.add_argument("--visible-report", type=Path, required=True)
            parser.add_argument("--review-ledger", type=Path, required=True)
        if name == "freeze-retrieval-benchmark":
            parser.add_argument("--developer-id", action="append", required=True)
            parser.add_argument("--visible-evaluation", type=Path, action="append", required=True)
        if name == "prepare-retrieval-release":
            for field in ("benchmark-freeze", "submission", "holdout-ledger", "holdout-report"):
                parser.add_argument("--" + field, type=Path)


def dispatch_pipeline_command(args: argparse.Namespace, workspace: Path):
    handler = _HANDLERS.get(args.command)
    if handler is None:
        return False, None
    # Resolve paths before reading or writing. Book/evaluation artifacts never escape workspace.
    workspace = workspace.resolve()
    for key, value in vars(args).items():
        paths = value if isinstance(value, list) else [value]
        resolved = []
        for path in paths:
            if isinstance(path, Path):
                path = (workspace / path).resolve()
                if not path.is_relative_to(workspace):
                    raise ManualGraphError("pipeline path must remain within workspace")
            resolved.append(path)
        setattr(args, key, resolved if isinstance(value, list) else resolved[0])
    for key in ("output", "ledger_output", "cache"):
        if getattr(args, key, None):
            local_path(workspace, getattr(args, key))
    if args.command == "search-released-evidence":
        return True, handler(args, workspace)
    if args.output.exists():
        raise ManualGraphError("output exists; use a new artifact revision to preserve evidence")
    result = handler(args, workspace)
    writer = write_once_atomic if args.command == "apply-retrieval-review-import" else write_once
    writer(args.output, result)
    return True, {"status": result.get("mode", result.get("status", "artifact_created")),
                  "content_sha256": result.get("content_sha256", content_sha256(result)),
                  "release_ready": result.get("release_ready", False),
                  "gate_failures": result.get("gate_failures", []), "output": str(args.output)}


def _visible_registry(_, workspace):
    return build_visible_registry(workspace)


def _repair_inventory(args, workspace):
    return build_repair_inventory(workspace, load_json(args.base_inventory), args.registry)


def _export_case_review(args, _):
    return build_case_review_export(
        cases=load_json(args.cases), corpus_freeze=load_json(args.corpus_freeze),
        ledger=load_json(args.ledger), chunks_path=args.chunks,
        owner_approval=load_json(args.owner_approval) if args.owner_approval else None,
    )


def _export_graph_review(args, _):
    return build_graph_review_export(
        candidate=load_json(args.graph_candidate), corpus_freeze=load_json(args.corpus_freeze),
        ledger=load_json(args.ledger), chunks_path=args.chunks,
    )


def _review_import_inputs(args):
    return load_json(args.target), load_json(args.corpus_freeze), load_json(args.ledger), load_json(args.batch)


def _plan_review_import(args, _):
    target, freeze, ledger, batch = _review_import_inputs(args)
    if batch.get("target_kind") != args.target_kind:
        raise ManualGraphError("target-kind does not match the review batch")
    return plan_review_import(target=target, corpus_freeze=freeze, ledger=ledger,
                              batch=batch, batch_path=args.batch)


def _apply_review_import(args, _):
    target, freeze, ledger, batch = _review_import_inputs(args)
    if batch.get("target_kind") != args.target_kind:
        raise ManualGraphError("target-kind does not match the review batch")
    return apply_review_import(target=target, corpus_freeze=freeze, ledger=ledger,
        batch=batch, batch_path=args.batch, plan=load_json(args.plan))


def _embedding(args, workspace):
    return build_embedding_index(chunks_path=args.chunks, corpus_freeze=load_json(args.corpus_freeze),
        encoder=OllamaEncoder(args.endpoint, args.model_digest), cache_dir=local_path(workspace, args.cache))


def _review_draft(args, _):
    freeze = load_json(args.corpus_freeze)
    validate_retrieval_corpus_binding(corpus_freeze=freeze, chunks_path=args.chunks)
    return build_visible_review_draft(load_json(args.cases), load_retrieval_chunks(args.chunks), freeze)


def _catalog_evidence(args, workspace):
    chunks, retrievers, bindings = _suite(args)
    if args.strategy not in retrievers:
        raise ManualGraphError("requested evidence strategy is unavailable")
    return build_catalog_evidence_packet(claims=load_json(local_path(workspace, args.claims)), chunks=chunks,
        retriever=retrievers[args.strategy], bindings=bindings, strategy=args.strategy)


def _candidate(args, workspace):
    freeze = load_json(args.corpus_freeze)
    validate_retrieval_corpus_binding(corpus_freeze=freeze, chunks_path=args.chunks)
    candidate = build_graph_candidate(load_retrieval_chunks(args.chunks), freeze)
    write_once(args.ledger_output, empty_graph_review(candidate, freeze))
    return candidate


def _inspect_graph(args, _):
    freeze = load_json(args.corpus_freeze)
    validate_retrieval_corpus_binding(corpus_freeze=freeze, chunks_path=args.chunks)
    return inspect_graph(load_json(args.graph_candidate), freeze)


def _graph_review(args, _):
    return record_graph_review(load_json(args.graph_candidate), load_json(args.corpus_freeze),
        load_json(args.graph_ledger), args.record_id, args.decision, args.reviewer_id, args.reviewer_role, args.comment)


def _materialize(args, _):
    return materialize_graph(load_json(args.graph_candidate), load_json(args.corpus_freeze), load_json(args.graph_ledger))


def _suite(args):
    index = load_json(args.index) if args.index else None
    encoder = OllamaEncoder(args.endpoint, index["model"]["digest"]) if index else None
    return create_suite(chunks_path=args.chunks, corpus_freeze=load_json(args.corpus_freeze),
        config=load_json(args.config), encoder=encoder, index=index,
        candidate=load_json(args.graph_candidate) if args.graph_candidate else None,
        ledger=load_json(args.graph_ledger) if args.graph_ledger else None,
        graph=load_json(args.graph) if args.graph else None)


def _benchmark(args, _):
    chunks, retrievers, bindings = _suite(args)
    cases = load_json(args.cases)
    if cases.get("corpus", {}).get("corpus_freeze_sha256") != bindings["corpus_freeze_sha256"]:
        raise ManualGraphError("benchmark cases use a different corpus freeze")
    return benchmark(cases=cases, chunks=chunks, retrievers=retrievers, bindings=bindings)


def _freeze(args, workspace):
    chunks, _, bindings = _suite(args)
    known_visible = workspace / "backend/services/nutrition/tools/nutrition_knowledge_manual/evaluation"
    visible_paths = set(args.visible_evaluation) | set(known_visible.glob("retrieval-eval*.json"))
    return freeze_benchmark(report=load_json(args.visible_report), cases=load_json(args.cases),
        chunks=chunks, bindings=bindings, corpus_freeze=load_json(args.corpus_freeze),
        ledger=load_json(args.review_ledger), developers=args.developer_id,
        visible_evaluations=[load_json(p) for p in sorted(visible_paths)])


def _seal(args, _):
    return seal_for_benchmark(load_json(args.submission), load_json(args.corpus_freeze),
        [load_json(p) for p in args.visible_evaluation], load_json(args.benchmark_freeze))


def _holdout(args, workspace):
    chunks, retrievers, bindings = _suite(args)
    report, _ = consume_holdout(workspace=workspace, submission=load_json(args.submission),
        marker=load_json(args.holdout_marker), freeze=load_json(args.benchmark_freeze),
        corpus_freeze=load_json(args.corpus_freeze), ledger=load_json(args.review_ledger),
        chunks=chunks, retrievers=retrievers, bindings=bindings)
    return report


def _release(args, workspace):
    chunks, _, bindings = _suite(args)
    return _release_evidence(args, workspace, chunks, bindings)


def _release_evidence(args, workspace, chunks, bindings):
    return release_manifest(workspace=workspace, visible_report=load_json(args.visible_report),
        visible_cases=load_json(args.cases), visible_ledger=load_json(args.review_ledger),
        corpus_freeze=load_json(args.corpus_freeze), chunks=chunks, bindings=bindings,
        freeze=load_json(args.benchmark_freeze) if args.benchmark_freeze else None,
        submission=load_json(args.submission) if args.submission else None,
        holdout_ledger=load_json(args.holdout_ledger) if args.holdout_ledger else None,
        holdout_report=load_json(args.holdout_report) if args.holdout_report else None)


def _search(args, workspace):
    manifest = load_json(local_path(workspace, args.release_manifest))
    require_internal_search_release(manifest)
    if manifest.get("code") != code_identity():
        raise ManualGraphError("retrieval release was built with different code")
    chunks, retrievers, bindings = _suite(args)
    rebuilt = _release_evidence(args, workspace, chunks, bindings)
    strategy = manifest["selected_strategy"]
    if strategy not in retrievers:
        raise ManualGraphError("released retrieval strategy is unavailable")
    search = ReleasedEvidenceSearch(manifest=manifest, rebuilt_manifest=rebuilt,
                                    chunks=chunks, retriever=retrievers[strategy])
    filters = {"source_revision_id": args.source_revision_id} if args.source_revision_id else None
    return search.search(args.question, args.top_k, filters)


_HANDLERS = {
    "build-visible-registry": _visible_registry,
    "build-repair-inventory": _repair_inventory,
    "export-retrieval-case-review": _export_case_review,
    "export-retrieval-graph-review": _export_graph_review,
    "plan-retrieval-review-import": _plan_review_import,
    "apply-retrieval-review-import": _apply_review_import,
    "build-retrieval-review-draft": _review_draft,
    "build-catalog-evidence-packet": _catalog_evidence,
    "build-retrieval-embedding-index": _embedding,
    "build-retrieval-graph-candidate": _candidate,
    "inspect-retrieval-graph": _inspect_graph,
    "review-retrieval-graph-record": _graph_review,
    "materialize-retrieval-graph": _materialize,
    "run-retrieval-benchmark": _benchmark,
    "freeze-retrieval-benchmark": _freeze,
    "seal-retrieval-benchmark-holdout": _seal,
    "run-retrieval-holdout": _holdout,
    "prepare-retrieval-release": _release,
    "search-released-evidence": _search,
}
