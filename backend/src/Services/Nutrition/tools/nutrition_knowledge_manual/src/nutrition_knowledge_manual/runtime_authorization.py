"""Explicit human runtime authorization. Integrity hashes are not identity authentication."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

from .errors import ManualGraphError
from .review_policy import DEFAULT, check, metadata, validate_metadata, add_argument
from .retrieval_artifacts import local_path, sign, verify, write_once_atomic

MODE = "runtime-integration-authorization"
STRATEGIES = {"keyword", "graph", "vector", "hybrid"}
ROLES = {"data_steward", "dietitian", "physician"}


def validate_manifest(manifest_bytes: bytes) -> dict:
    manifest = json.loads(manifest_bytes)
    verify(manifest, "retrieval_release_manifest")
    validate_metadata(manifest, manifest.get("review_policy"))
    strategy = manifest.get("selected_strategy")
    if (manifest.get("release_ready") is not True or manifest.get("gate_failures") != []
            or strategy not in STRATEGIES
            or manifest.get("decision") != "simplest_strategy_passing_all_gates"
            or manifest.get("strategy_gate_failures", {}).get(strategy) != []):
        raise ManualGraphError("runtime authorization requires a release-ready manifest without gate failures")
    for key in ("benchmark_freeze_sha256", "holdout_report_sha256", "holdout_review_sha256"):
        if not _digest(manifest.get(key)):
            raise ManualGraphError("runtime authorization requires consumed holdout evidence bindings")
    return manifest


def _digest(value) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def create_runtime_authorization(manifest_bytes: bytes, *, environment: str,
                                 reviewer_id: str, role: str, comment: str, review_policy=DEFAULT) -> dict:
    manifest = validate_manifest(manifest_bytes)
    validate_metadata(manifest, review_policy)
    check(review_policy, role=role)
    result = sign({**metadata(review_policy), "schema_version": 1, "mode": MODE,
                   "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
                   "environment": environment, "selected_strategy": manifest["selected_strategy"],
                   "reviewer_id": reviewer_id, "role": role,
                   "timestamp": datetime.now(timezone.utc).isoformat(), "comment": comment})
    verify_runtime_authorization(result, manifest_bytes, environment=environment)
    return result


def verify_runtime_authorization(authorization: dict, manifest_bytes: bytes, *, environment: str) -> None:
    manifest = validate_manifest(manifest_bytes)
    verify(authorization, MODE)
    validate_metadata(authorization, manifest["review_policy"])
    check(manifest["review_policy"], authorization)
    if (environment not in {"Staging", "Production"} or authorization.get("environment") != environment
            or authorization.get("manifest_sha256") != hashlib.sha256(manifest_bytes).hexdigest()
            or authorization.get("selected_strategy") != manifest["selected_strategy"]
            or authorization.get("role") not in ROLES
            or any(not isinstance(authorization.get(k), str) or not authorization[k].strip()
                   for k in ("reviewer_id", "comment", "timestamp"))):
        raise ManualGraphError("runtime authorization binding or signer is invalid")
    try:
        timestamp = datetime.fromisoformat(authorization["timestamp"])
        if timestamp.utcoffset() is None or timestamp.utcoffset().total_seconds() != 0:
            raise ValueError()
    except ValueError:
        raise ManualGraphError("runtime authorization requires a UTC timestamp") from None


def register_runtime_commands(commands: argparse._SubParsersAction) -> None:
    for name in ("create-runtime-authorization", "verify-runtime-authorization"):
        parser = commands.add_parser(name)
        add_argument(parser)
        parser.add_argument("--release-manifest", type=Path, required=True)
        parser.add_argument("--environment", choices=["Staging", "Production"], required=True)
        if name.startswith("create"):
            parser.add_argument("--output", type=Path, required=True)
            parser.add_argument("--reviewer-id", required=True)
            parser.add_argument("--role", choices=sorted(ROLES), required=True)
            parser.add_argument("--comment", required=True)
        else:
            parser.add_argument("--authorization", type=Path, required=True)


def dispatch_runtime_command(args, workspace: Path):
    if args.command not in {"create-runtime-authorization", "verify-runtime-authorization"}:
        return False, None
    manifest_bytes = local_path(workspace, args.release_manifest).read_bytes()
    validate_metadata(validate_manifest(manifest_bytes), args.review_policy)
    if args.command.startswith("create"):
        authorization = create_runtime_authorization(manifest_bytes, environment=args.environment,
            reviewer_id=args.reviewer_id, role=args.role, comment=args.comment, review_policy=args.review_policy)
        write_once_atomic(local_path(workspace, args.output), authorization)
    else:
        authorization = json.loads(local_path(workspace, args.authorization).read_bytes())
        verify_runtime_authorization(authorization, manifest_bytes, environment=args.environment)
    return True, {"status": "runtime_authorization_valid", "content_sha256": authorization["content_sha256"]}
