from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .freeze import validate_frozen_inputs
from .jsonio import load_json, sha256_file, write_json


def build_report(
    *, module_root: Path, artifact_root: Path, freeze_path: Path, preflight_path: Path, output_path: Path
) -> dict[str, Any]:
    freeze = validate_frozen_inputs(module_root, freeze_path)
    preflight = load_json(preflight_path)
    baseline_path = artifact_root / "manual-baseline.json"
    baseline = load_json(baseline_path) if baseline_path.exists() else None
    models = [item["tag"] for item in load_json(module_root / "config" / "models.json")["extractors"]]
    selection: dict[str, Any] = {}
    for model in models:
        safe = model.replace(":", "_")
        path = artifact_root / "benchmarks" / freeze["content_sha256"] / safe / "selection-summary.json"
        if path.exists():
            selection[model] = load_json(path)
    addendum_path = artifact_root / "freezes" / f"{freeze['content_sha256']}.selection.json"
    addendum = load_json(addendum_path) if addendum_path.exists() else None
    selected_model = addendum.get("selected_model") if addendum else None
    holdout = None
    if selected_model:
        safe = selected_model.replace(":", "_")
        holdout_path = artifact_root / "benchmarks" / freeze["content_sha256"] / safe / "holdout-summary.json"
        holdout = load_json(holdout_path) if holdout_path.exists() else None
    offline_path = artifact_root / "offline-gate" / f"{freeze['content_sha256']}.json"
    offline = load_json(offline_path) if offline_path.exists() else None
    holdout_passed = bool(holdout and holdout.get("gate", {}).get("decision") == "pass")
    offline_passed = bool(offline and offline.get("passed") is True)
    decision = "go_g1_with_reviewed_fixture" if holdout_passed and offline_passed else "no_go_or_pending"
    report = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "technical screening on synthetic fixtures only; no clinical or real-book claim",
        "freeze_file_sha256": sha256_file(freeze_path),
        "freeze_content_sha256": freeze["content_sha256"],
        "preflight": preflight,
        "manual_baseline": baseline,
        "selection": selection,
        "selection_addendum": addendum,
        "offline_gate": offline,
        "holdout": holdout,
        "decision": decision,
        "real_source_decision": "no_go while rights_status remains unverified",
    }
    write_json(output_path, report)
    return report
