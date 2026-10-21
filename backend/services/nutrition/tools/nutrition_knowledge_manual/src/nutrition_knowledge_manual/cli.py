from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .errors import ManualGraphError
from .catalog_authoring import finalize_catalog_candidate, prepare_catalog_candidate
from .catalog_review import (
    catalog_review_status,
    empty_catalog_review,
    record_catalog_clinical_review,
    record_recipe_review,
)
from .chunk_pdf import chunk_pdf_source
from .chunk_html import chunk_html_source
from .graph import build_candidate_graph
from .jsonio import file_sha256, load_json, write_json
from .review import append_decision, empty_decision_ledger, materialize_reviewed_graph
from .release import prepare_release
from .rights import resolve_source


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="CareSitter fail-closed manual nutrition graph pipeline")
    root.add_argument("--workspace", type=Path, required=True)
    commands = root.add_subparsers(dest="command", required=True)
    chunk = commands.add_parser("chunk-pdf")
    chunk.add_argument("--manifest", type=Path, required=True)
    chunk.add_argument("--source-id", required=True)
    chunk.add_argument("--output", type=Path, required=True)
    chunk.add_argument("--report", type=Path, required=True)
    chunk.add_argument("--target-tokens", type=int, default=450)
    chunk.add_argument("--maximum-tokens", type=int, default=700)
    chunk.add_argument("--overlap-tokens", type=int, default=60)
    chunk_html = commands.add_parser("chunk-html")
    chunk_html.add_argument("--manifest", type=Path, required=True)
    chunk_html.add_argument("--source-id", required=True)
    chunk_html.add_argument("--output", type=Path, required=True)
    chunk_html.add_argument("--report", type=Path, required=True)
    chunk_html.add_argument("--target-tokens", type=int, default=450)
    chunk_html.add_argument("--maximum-tokens", type=int, default=700)
    chunk_html.add_argument("--overlap-tokens", type=int, default=60)
    build = commands.add_parser("build-candidates")
    build.add_argument("--manifest", type=Path, required=True)
    build.add_argument("--source-id", required=True)
    build.add_argument("--output", type=Path, required=True)
    init = commands.add_parser("init-review")
    init.add_argument("--graph", type=Path, required=True)
    init.add_argument("--output", type=Path, required=True)
    review = commands.add_parser("review")
    review.add_argument("--graph", type=Path, required=True)
    review.add_argument("--ledger", type=Path, required=True)
    review.add_argument("--policy", type=Path, required=True)
    review.add_argument("--candidate-id", required=True)
    review.add_argument("--decision", choices=["approve", "reject"], required=True)
    review.add_argument("--reviewer-id", required=True)
    review.add_argument("--reviewer-role", required=True)
    review.add_argument("--comment", required=True)
    materialize = commands.add_parser("materialize")
    materialize.add_argument("--graph", type=Path, required=True)
    materialize.add_argument("--ledger", type=Path, required=True)
    materialize.add_argument("--policy", type=Path, required=True)
    materialize.add_argument("--output", type=Path, required=True)
    release = commands.add_parser("prepare-release")
    release.add_argument("--manifest", type=Path, required=True)
    release.add_argument("--source-id", required=True)
    release.add_argument("--evidence", type=Path, required=True)
    release.add_argument("--graph", type=Path, required=True)
    release.add_argument("--ledger", type=Path, required=True)
    release.add_argument("--policy", type=Path, required=True)
    release.add_argument("--output-evidence", type=Path, required=True)
    release.add_argument("--output-authorization", type=Path, required=True)
    prepare_catalog = commands.add_parser("prepare-catalog-candidate")
    prepare_catalog.add_argument("--profile", type=Path, required=True)
    prepare_catalog.add_argument("--draft", type=Path, required=True)
    prepare_catalog.add_argument("--food-snapshot", type=Path, required=True)
    prepare_catalog.add_argument("--output-dir", type=Path, required=True)
    finalize_catalog = commands.add_parser("finalize-catalog-candidate")
    finalize_catalog.add_argument("--profile", type=Path, required=True)
    finalize_catalog.add_argument("--candidate-manifest", type=Path, required=True)
    finalize_catalog.add_argument("--candidate-bundle", type=Path, required=True)
    finalize_catalog.add_argument("--candidate-evidence", type=Path, required=True)
    finalize_catalog.add_argument("--decisions", type=Path, required=True)
    finalize_catalog.add_argument("--output-dir", type=Path, required=True)
    init_catalog_review = commands.add_parser("init-catalog-review")
    init_catalog_review.add_argument("--candidate-manifest", type=Path, required=True)
    init_catalog_review.add_argument("--output", type=Path, required=True)
    review_recipe = commands.add_parser("review-catalog-recipe")
    review_recipe.add_argument("--candidate-manifest", type=Path, required=True)
    review_recipe.add_argument("--ledger", type=Path, required=True)
    review_recipe.add_argument("--recipe-version-id", required=True)
    review_recipe.add_argument("--decision", choices=["approved", "rejected"], required=True)
    review_recipe.add_argument("--reviewer-id", required=True)
    review_recipe.add_argument("--reviewer-role", choices=["data_steward", "dietitian", "physician"], required=True)
    review_recipe.add_argument("--comment", required=True)
    review_recipe.add_argument("--resolutions", type=Path)
    review_catalog = commands.add_parser("review-catalog-release")
    review_catalog.add_argument("--candidate-manifest", type=Path, required=True)
    review_catalog.add_argument("--ledger", type=Path, required=True)
    review_catalog.add_argument("--reviewer-name", required=True)
    review_catalog.add_argument("--reviewer-id", required=True)
    review_catalog.add_argument("--credentials", required=True)
    review_catalog.add_argument("--decision", choices=["approved", "rejected"], required=True)
    review_catalog.add_argument("--notes")
    review_status = commands.add_parser("catalog-review-status")
    review_status.add_argument("--candidate-manifest", type=Path, required=True)
    review_status.add_argument("--candidate-evidence", type=Path, required=True)
    review_status.add_argument("--ledger", type=Path, required=True)
    return root


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        result = dispatch(args)
    except (ManualGraphError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


def dispatch(args: argparse.Namespace) -> dict:
    workspace = args.workspace.resolve()
    if args.command == "chunk-pdf":
        return chunk_pdf_source(
            workspace=workspace, manifest_path=args.manifest, source_id=args.source_id,
            output_path=args.output, report_path=args.report, target_tokens=args.target_tokens,
            maximum_tokens=args.maximum_tokens, overlap_tokens=args.overlap_tokens
        )
    if args.command == "chunk-html":
        return chunk_html_source(
            workspace=workspace, manifest_path=args.manifest, source_id=args.source_id,
            output_path=args.output, report_path=args.report, target_tokens=args.target_tokens,
            maximum_tokens=args.maximum_tokens, overlap_tokens=args.overlap_tokens
        )
    if args.command == "build-candidates":
        source, source_path = resolve_source(workspace=workspace, manifest_path=args.manifest, source_id=args.source_id)
        result = build_candidate_graph(load_json(source_path), source)
        write_json(args.output, result)
        return _summary(result)
    if args.command == "prepare-catalog-candidate":
        result = prepare_catalog_candidate(
            profile=load_json(args.profile),
            draft=load_json(args.draft),
            food_snapshot=load_json(args.food_snapshot),
            input_file_sha256={
                "draft": file_sha256(args.draft),
                "food_snapshot": file_sha256(args.food_snapshot),
            },
        )
        package_key = result["manifest"]["package_key"]
        paths = {
            "bundle": args.output_dir / f"{package_key}.candidate.bundle.json",
            "evidence": args.output_dir / f"{package_key}.candidate.evidence.json",
            "review_packet": args.output_dir / f"{package_key}.review-packet.json",
            "manifest": args.output_dir / f"{package_key}.candidate-manifest.json",
        }
        for key, path in paths.items():
            write_json(path, result[key])
        return {
            "status": result["manifest"]["status"],
            "candidate_manifest_sha256": result["manifest"]["content_sha256"],
            "recipe_count": len(result["bundle"]["recipes"]),
            "combination_count": result["review_packet"]["combination_coverage"]["combination_count"],
            "outputs": {key: str(path.resolve()) for key, path in paths.items()},
        }
    if args.command == "finalize-catalog-candidate":
        result = finalize_catalog_candidate(
            profile=load_json(args.profile),
            candidate_manifest=load_json(args.candidate_manifest),
            candidate_bundle=load_json(args.candidate_bundle),
            candidate_evidence=load_json(args.candidate_evidence),
            decisions=load_json(args.decisions),
        )
        package_key = result["manifest"]["package_key"]
        paths = {
            "bundle": args.output_dir / f"{package_key}.release.bundle.json",
            "evidence": args.output_dir / f"{package_key}.release.evidence.json",
            "manifest": args.output_dir / f"{package_key}.release-manifest.json",
        }
        for key, path in paths.items():
            write_json(path, result[key])
        return {
            "status": result["manifest"]["status"],
            "release_manifest_sha256": result["manifest"]["content_sha256"],
            "outputs": {key: str(path.resolve()) for key, path in paths.items()},
        }
    if args.command == "init-catalog-review":
        result = empty_catalog_review(load_json(args.candidate_manifest))
        write_json(args.output, result)
        return {
            "status": "catalog_review_initialized",
            "candidate_manifest_sha256": result["candidate_manifest_sha256"],
            "recipe_count": len(result["decisions"]),
            "ledger_content_sha256": result["content_sha256"],
            "output": str(args.output.resolve()),
        }
    if args.command == "review-catalog-recipe":
        resolutions = load_json(args.resolutions) if args.resolutions else []
        result = record_recipe_review(
            candidate_manifest=load_json(args.candidate_manifest),
            ledger=load_json(args.ledger),
            recipe_version_id=args.recipe_version_id,
            decision=args.decision,
            reviewer_id=args.reviewer_id,
            reviewer_role=args.reviewer_role,
            comment=args.comment,
            resolutions=resolutions,
        )
        write_json(args.ledger, result)
        return {
            "status": "recipe_review_recorded",
            "recipe_version_id": args.recipe_version_id,
            "reviewer_role": args.reviewer_role,
            "decision": args.decision,
            "ledger_content_sha256": result["content_sha256"],
        }
    if args.command == "review-catalog-release":
        result = record_catalog_clinical_review(
            candidate_manifest=load_json(args.candidate_manifest),
            ledger=load_json(args.ledger),
            reviewer_name=args.reviewer_name,
            reviewer_id=args.reviewer_id,
            credentials=args.credentials,
            decision=args.decision,
            notes=args.notes,
        )
        write_json(args.ledger, result)
        return {
            "status": "catalog_clinical_review_recorded",
            "decision": args.decision,
            "reviewer_id": args.reviewer_id,
            "ledger_content_sha256": result["content_sha256"],
        }
    if args.command == "catalog-review-status":
        return catalog_review_status(
            candidate_manifest=load_json(args.candidate_manifest),
            candidate_evidence=load_json(args.candidate_evidence),
            ledger=load_json(args.ledger),
        )
    graph = load_json(args.graph)
    if args.command == "init-review":
        result = empty_decision_ledger(graph)
        write_json(args.output, result)
        return result
    ledger = load_json(args.ledger)
    policy = load_json(args.policy)
    if args.command == "review":
        result = append_decision(
            graph=graph, ledger=ledger, candidate_id=args.candidate_id, decision=args.decision,
            reviewer_id=args.reviewer_id, reviewer_role=args.reviewer_role, comment=args.comment, policy=policy
        )
        write_json(args.ledger, result)
        return {"decision_count": len(result["decisions"]), "graph_content_sha256": result["graph_content_sha256"]}
    if args.command == "materialize":
        result = materialize_reviewed_graph(graph, ledger, policy)
        write_json(args.output, result)
        return _summary(result)
    if args.command == "prepare-release":
        evidence, authorization = prepare_release(
            workspace=workspace, manifest_path=args.manifest, bundle_source_id=args.source_id,
            evidence_path=args.evidence, graph=graph, ledger=ledger, policy=policy
        )
        write_json(args.output_evidence, evidence)
        write_json(args.output_authorization, authorization)
        return {
            "status": authorization["status"],
            "package_key": authorization["package_key"],
            "authorization_sha256": authorization["content_sha256"],
            "evidence_content_sha256": authorization["evidence_content_sha256"],
        }
    raise ManualGraphError(f"unsupported command: {args.command}")


def _summary(value: dict) -> dict:
    return {key: value[key] for key in (
        "schema_version", "mode", "content_sha256", "candidate_count", "automatic_admissions",
        "record_count", "pending_count", "rejected_count", "blocked_edge_candidate_ids"
    ) if key in value}
