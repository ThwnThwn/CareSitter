from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import re
from typing import Any

from .errors import ContractError, GateError
from .fixtures import FixtureCase, load_cases, validate_prediction_shape
from .freeze import validate_frozen_inputs, validate_frozen_models
from .gates import evaluate_run
from .jsonio import load_json, sha256_file, write_json
from .manifest import assert_use_allowed, validate_manifest
from .ollama import OllamaClient
from .scoring import bootstrap_case_pairs, compare_runs, percentile, score_run


def probe_context(module_root: Path, model_tags: list[str], ollama: OllamaClient) -> dict[str, Any]:
    schema = load_json(module_root / "config" / "extraction.schema.json")
    ontology = load_json(module_root / "config" / "ontology.json")
    options = load_json(module_root / "config" / "thresholds.json")["generation_options"]
    prompt_template = (module_root / "config" / "prompt.txt").read_text(encoding="utf-8")
    dev_cases = load_cases(module_root / "fixtures" / "dev.json")
    longest = max(dev_cases, key=lambda item: len(_build_prompt(prompt_template, ontology, item)))
    prompt = _build_prompt(prompt_template, ontology, longest)
    results: dict[str, Any] = {}
    for model_tag in model_tags:
        show = ollama.show(model_tag)
        think = False if "thinking" in show.get("capabilities", []) else None
        generated = ollama.generate(model=model_tag, prompt=prompt, schema=schema, options=options, think=think)
        context_valid = (
            generated.done_reason == "stop"
            and generated.prompt_eval_count + options["num_predict"] <= options["num_ctx"]
        )
        results[model_tag] = {
            "dev_case_id": longest.case_id,
            "prompt_characters": len(prompt),
            "prompt_eval_count": generated.prompt_eval_count,
            "num_ctx": options["num_ctx"],
            "num_predict": options["num_predict"],
            "done_reason": generated.done_reason,
            "context_valid": context_valid,
        }
        if not context_valid:
            raise GateError(
                f"Context probe failed for {model_tag}: done_reason={generated.done_reason}, "
                f"prompt_eval_count={generated.prompt_eval_count}, eval_count={generated.eval_count}, "
                f"error={generated.error or 'none'}; revise the frozen runtime contract"
            )
    return results


def run_selection(
    *,
    module_root: Path,
    artifact_root: Path,
    freeze_path: Path,
    model_tag: str,
    ollama: OllamaClient,
) -> dict[str, Any]:
    freeze = _validate_benchmark(module_root, freeze_path, model_tag, ollama)
    model = _frozen_model(freeze, model_tag)
    _assert_fixture_use(module_root, "selection")
    output_root = _result_root(artifact_root, freeze, model_tag)
    cases = load_cases(module_root / "fixtures" / "selection.json")
    runs = [
        _run_once(module_root, output_root, "selection", run_number, cases, model, freeze, ollama)
        for run_number in (1, 2)
    ]
    first_predictions = runs[0]["predictions"]
    second_predictions = runs[1]["predictions"]
    ontology = load_json(module_root / "config" / "ontology.json")
    summary = {
        "schema_version": 1,
        "split": "selection",
        "model": model_tag,
        "freeze_sha256": sha256_file(freeze_path),
        "freeze_content_sha256": freeze["content_sha256"],
        "runs": [{key: value for key, value in item.items() if key != "predictions"} for item in runs],
        "stability": compare_runs(first_predictions, second_predictions),
        "bootstrap": bootstrap_case_pairs(cases, first_predictions, second_predictions, ontology),
    }
    summary["decision"] = "pass" if all(item["gate"]["decision"] == "pass" for item in runs) else (
        "inconclusive" if all(item["gate"]["decision"] != "fail" for item in runs) else "fail"
    )
    write_json(output_root / "selection-summary.json", summary)
    return summary


def record_selection(
    *, module_root: Path, artifact_root: Path, freeze_path: Path, model_tag: str
) -> dict[str, Any]:
    freeze = validate_frozen_inputs(module_root, freeze_path)
    selected_by_rule = _best_model(module_root, artifact_root, freeze)
    if model_tag != selected_by_rule["model"]:
        raise GateError(f"Selection rule chose {selected_by_rule['model']}, not {model_tag}")
    output_root = _result_root(artifact_root, freeze, model_tag)
    summary = load_json(output_root / "selection-summary.json")
    if summary.get("decision") != "pass":
        raise GateError(f"Model {model_tag} did not pass both selection runs")
    addendum_path = artifact_root / "freezes" / f"{freeze['content_sha256']}.selection.json"
    if addendum_path.exists():
        raise ContractError(f"Selection addendum already exists: {addendum_path}")
    addendum = {
        "schema_version": 1,
        "freeze_content_sha256": freeze["content_sha256"],
        "freeze_file_sha256": sha256_file(freeze_path),
        "selected_model": model_tag,
        "selection_rule": selected_by_rule,
        "selection_summary_sha256": sha256_file(output_root / "selection-summary.json"),
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    write_json(addendum_path, addendum)
    return addendum


def run_holdout(
    *,
    module_root: Path,
    artifact_root: Path,
    freeze_path: Path,
    ollama: OllamaClient,
) -> dict[str, Any]:
    freeze = validate_frozen_inputs(module_root, freeze_path)
    addendum_path = artifact_root / "freezes" / f"{freeze['content_sha256']}.selection.json"
    addendum = load_json(addendum_path)
    if addendum.get("freeze_file_sha256") != sha256_file(freeze_path):
        raise ContractError("Selection addendum does not match the freeze file")
    model_tag = addendum["selected_model"]
    _validate_benchmark(module_root, freeze_path, model_tag, ollama)
    offline_gate_path = artifact_root / "offline-gate" / f"{freeze['content_sha256']}.json"
    if not offline_gate_path.exists():
        raise GateError("A passed two-layer offline gate artifact is required before consuming holdout")
    _validate_offline_gate(load_json(offline_gate_path), freeze["content_sha256"])
    output_root = _result_root(artifact_root, freeze, model_tag)
    selection_summary_path = output_root / "selection-summary.json"
    if addendum.get("selection_summary_sha256") != sha256_file(selection_summary_path):
        raise ContractError("Selected model summary changed after selection was recorded")
    consumed = artifact_root / "holdout-consumed" / f"{freeze['content_sha256']}.json"
    consumed.parent.mkdir(parents=True, exist_ok=True)
    try:
        with consumed.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump({
                "freeze_content_sha256": freeze["content_sha256"],
                "model": model_tag,
                "started_at_utc": datetime.now(timezone.utc).isoformat(),
            }, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
    except FileExistsError as error:
        raise GateError("Holdout is already consumed for this freeze revision") from error
    cases = load_cases(module_root / "fixtures" / "holdout.json")
    _assert_fixture_use(module_root, "holdout")
    result = _run_once(module_root, output_root, "holdout", 1, cases, _frozen_model(freeze, model_tag), freeze, ollama)
    summary = {key: value for key, value in result.items() if key != "predictions"}
    write_json(output_root / "holdout-summary.json", summary)
    return summary


def _run_once(
    module_root: Path,
    output_root: Path,
    split: str,
    run_number: int,
    cases: list[FixtureCase],
    model: dict[str, Any],
    freeze: dict[str, Any],
    ollama: OllamaClient,
) -> dict[str, Any]:
    target = output_root / f"{split}-run-{run_number}.json"
    if target.exists():
        raise ContractError(f"Refusing to overwrite a benchmark run: {target}")
    schema = load_json(module_root / "config" / "extraction.schema.json")
    ontology = load_json(module_root / "config" / "ontology.json")
    thresholds = load_json(module_root / "config" / "thresholds.json")
    prompt_template = (module_root / "config" / "prompt.txt").read_text(encoding="utf-8")
    options = dict(freeze["options"])
    think = False if model.get("thinking_supported") else None
    predictions: dict[str, dict[str, Any]] = {}
    telemetry_rows: list[dict[str, Any]] = []
    warmup_case = load_cases(module_root / "fixtures" / "dev.json")[0]
    warmup = ollama.generate(
        model=model["tag"],
        prompt=_build_prompt(prompt_template, ontology, warmup_case),
        schema=schema,
        options=options,
        think=think,
    )
    if warmup.done_reason != "stop":
        raise GateError(f"Warm-up failed for {model['tag']}: {warmup.error or warmup.done_reason}")
    for item in cases:
        prompt = _build_prompt(prompt_template, ontology, item)
        generated = ollama.generate(model=model["tag"], prompt=prompt, schema=schema, options=options, think=think)
        shape_valid, shape_error = validate_prediction_shape(generated.response)
        valid = generated.schema_valid and shape_valid
        if valid and generated.response is not None:
            predictions[item.case_id] = generated.response
        telemetry_rows.append({
            "case_id": item.case_id,
            "schema_valid": valid,
            "error": generated.error or shape_error,
            "prompt_eval_count": generated.prompt_eval_count,
            "eval_count": generated.eval_count,
            "done_reason": generated.done_reason,
            "context_valid": generated.done_reason == "stop" and generated.prompt_eval_count + options["num_predict"] <= options["num_ctx"],
            "wall_duration_seconds": generated.wall_duration_seconds,
            "ollama_ps": ollama.running_models(),
        })
    score = score_run(cases, predictions, ontology)
    telemetry = {
        "schema_valid_cases": sum(item["schema_valid"] for item in telemetry_rows),
        "context_valid_cases": sum(item["context_valid"] for item in telemetry_rows),
        "latency_p50_seconds": percentile([item["wall_duration_seconds"] for item in telemetry_rows], 0.50),
        "latency_p95_seconds": percentile([item["wall_duration_seconds"] for item in telemetry_rows], 0.95),
        "cases": telemetry_rows,
    }
    result = {
        "schema_version": 1,
        "split": split,
        "run": run_number,
        "model": model["tag"],
        "score": score,
        "telemetry": telemetry,
        "gate": evaluate_run(split, score, telemetry, thresholds),
        "predictions": predictions,
    }
    write_json(target, result)
    return result


def _validate_benchmark(module_root: Path, freeze_path: Path, model_tag: str, ollama: OllamaClient) -> dict[str, Any]:
    freeze = validate_frozen_inputs(module_root, freeze_path)
    validate_frozen_models(freeze, ollama)
    _frozen_model(freeze, model_tag)
    active = [item.get("name") or item.get("model") for item in ollama.running_models()]
    other = [item for item in active if item and item != model_tag]
    if other:
        raise GateError(f"Unload other Ollama models before benchmarking {model_tag}: {other}")
    return freeze


def _best_model(module_root: Path, artifact_root: Path, freeze: dict[str, Any]) -> dict[str, Any]:
    candidates = [item["tag"] for item in load_json(module_root / "config" / "models.json")["extractors"]]
    tie_delta = load_json(module_root / "config" / "thresholds.json")["selection_tie_delta"]
    rows: list[dict[str, Any]] = []
    for tag in candidates:
        summary_path = _result_root(artifact_root, freeze, tag) / "selection-summary.json"
        if not summary_path.exists():
            raise GateError(f"Selection result is missing for candidate: {tag}")
        summary = load_json(summary_path)
        if summary.get("freeze_content_sha256") != freeze.get("content_sha256"):
            raise ContractError(f"Selection summary belongs to another freeze: {tag}")
        if summary.get("decision") != "pass":
            continue
        frozen = _frozen_model(freeze, tag)
        rows.append({
            "model": tag,
            "relation_claim_f1_mean": sum(item["score"]["relation_claim"]["f1"] for item in summary["runs"]) / 2,
            "latency_p95_mean": sum(item["telemetry"]["latency_p95_seconds"] for item in summary["runs"]) / 2,
            "size": frozen.get("size") or 0,
        })
    if not rows:
        raise GateError("No extractor passed both selection runs")
    best_f1 = max(item["relation_claim_f1_mean"] for item in rows)
    tied = [item for item in rows if best_f1 - item["relation_claim_f1_mean"] <= tie_delta]
    return min(tied, key=lambda item: (item["latency_p95_mean"], item["size"], item["model"]))


def _assert_fixture_use(module_root: Path, split: str) -> None:
    workspace_root = module_root.parents[4]
    records = validate_manifest(module_root / "config" / "source-manifest.json", workspace_root)
    source_id = f"g0-{split}-fixtures"
    record = next((item for item in records if item.source_id == source_id), None)
    if record is None:
        raise GateError(f"Fixture source is not registered: {source_id}")
    assert_use_allowed(record, "local_query")


def _validate_offline_gate(value: dict[str, Any], freeze_content_sha256: str) -> None:
    required_true = (
        "passed",
        "adapters_disabled",
        "ollama_rules_applied",
        "no_pipeline_outbound_attempts",
        "python_positive_control_blocked",
    )
    if value.get("freeze_content_sha256") != freeze_content_sha256:
        raise GateError("Offline gate belongs to another freeze revision")
    if any(value.get(key) is not True for key in required_true):
        raise GateError("Offline gate did not pass every required control")
    if not value.get("executables") or not value.get("evidence"):
        raise GateError("Offline gate must identify executables and hashed evidence")


def _frozen_model(freeze: dict[str, Any], model_tag: str) -> dict[str, Any]:
    for item in freeze.get("models", []):
        if item["tag"] == model_tag:
            return item
    raise ContractError(f"Model is not part of this freeze: {model_tag}")


def _result_root(artifact_root: Path, freeze: dict[str, Any], model_tag: str) -> Path:
    safe_model = re.sub(r"[^A-Za-z0-9_.-]+", "_", model_tag)
    return artifact_root / "benchmarks" / freeze["content_sha256"] / safe_model


def _build_prompt(template: str, ontology: dict[str, Any], item: FixtureCase) -> str:
    spans = "\n".join(f"[{span.span_id}] {span.text}" for span in item.spans)
    return template.format(
        ontology=json.dumps(ontology, ensure_ascii=False, sort_keys=True),
        spans=spans,
    )
