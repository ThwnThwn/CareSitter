from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

from .errors import G0Error
from .jsonio import write_json
from .study import G0Study


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="CareSitter Nutrition local GraphRAG G0 gate")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("validate", help="Validate fixtures, ontology and rights manifest")
    baseline = commands.add_parser("baseline", help="Record the safe keyword/manual fallback")
    baseline.add_argument("--output", type=Path, required=True)
    preflight = commands.add_parser("preflight", help="Inspect the local runtime without parsing source content")
    preflight.add_argument("--output", type=Path)
    freeze = commands.add_parser("freeze", help="Freeze inputs and exact local model digests")
    freeze.add_argument("--output", type=Path, required=True)
    selection = commands.add_parser("benchmark-selection", help="Run both selection repetitions for one frozen model")
    selection.add_argument("--freeze", type=Path, required=True)
    selection.add_argument("--model", required=True)
    choose = commands.add_parser("record-selection", help="Record a model that passed both selection repetitions")
    choose.add_argument("--freeze", type=Path, required=True)
    choose.add_argument("--model", required=True)
    holdout = commands.add_parser("benchmark-holdout", help="Consume the sealed holdout once")
    holdout.add_argument("--freeze", type=Path, required=True)
    embedding = commands.add_parser("embedding-smoke", help="Run bge-m3 dimension, latency and top-3 smoke checks")
    embedding.add_argument("--freeze", type=Path, required=True)
    embedding.add_argument("--output", type=Path, required=True)
    report = commands.add_parser("report", help="Build a redacted G0 report without raw fixture text")
    report.add_argument("--freeze", type=Path, required=True)
    report.add_argument("--preflight", type=Path, required=True)
    report.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    study = G0Study()
    try:
        result = _dispatch(study, args)
    except (G0Error, OSError, ValueError, KeyError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


def _dispatch(study: G0Study, args: argparse.Namespace) -> dict[str, Any]:
    if args.command == "validate":
        return study.validate()
    if args.command == "baseline":
        return study.baseline(args.output)
    if args.command == "preflight":
        result = study.preflight()
        if args.output:
            write_json(study.require_artifact_path(args.output), result)
        return result
    if args.command == "freeze":
        return study.freeze(args.output)
    if args.command == "benchmark-selection":
        return study.benchmark_selection(args.freeze, args.model)
    if args.command == "record-selection":
        return study.select_model(args.freeze, args.model)
    if args.command == "benchmark-holdout":
        return study.benchmark_holdout(args.freeze)
    if args.command == "embedding-smoke":
        return study.embedding_smoke(args.freeze, args.output)
    if args.command == "report":
        return study.report(args.freeze, args.preflight, args.output)
    raise ValueError(f"Unsupported command: {args.command}")
