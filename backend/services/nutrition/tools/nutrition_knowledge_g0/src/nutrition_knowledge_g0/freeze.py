from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import platform
import sys
from typing import Any

from .errors import ContractError
from .jsonio import canonical_bytes, load_json, sha256_bytes, sha256_file, write_json
from .ollama import OllamaClient


def create_freeze(
    *,
    config_root: Path,
    output_path: Path,
    model_tags: list[str],
    ollama: OllamaClient,
    context_probe: dict[str, Any],
) -> dict[str, Any]:
    if output_path.exists():
        raise ContractError(f"Refusing to overwrite an existing freeze: {output_path}")
    inputs = {
        relative: sha256_file(config_root / relative)
        for relative in (
            "fixtures/dev.json",
            "fixtures/selection.json",
            "fixtures/holdout.json",
            "config/ontology.json",
            "config/extraction.schema.json",
            "config/manifest.schema.json",
            "config/models.json",
            "config/prompt.txt",
            "config/thresholds.json",
            "config/source-manifest.json",
        )
    }
    for relative in ("pyproject.toml", "requirements.lock"):
        inputs[relative] = sha256_file(config_root / relative)
    for path in sorted((config_root / "src").rglob("*.py")):
        relative = path.relative_to(config_root).as_posix()
        inputs[relative] = sha256_file(path)
    installed = ollama.tags()
    models: list[dict[str, Any]] = []
    for tag in model_tags:
        if tag not in installed:
            raise ContractError(f"Model is not installed under the exact tag: {tag}")
        tag_info = installed[tag]
        show = ollama.show(tag)
        details = tag_info.get("details", {})
        models.append({
            "tag": tag,
            "digest": tag_info.get("digest"),
            "size": tag_info.get("size"),
            "quantization": details.get("quantization_level"),
            "family": details.get("family"),
            "capabilities": show.get("capabilities", []),
            "thinking_supported": "thinking" in show.get("capabilities", []),
        })
    thresholds = load_json(config_root / "config/thresholds.json")
    freeze = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "inputs": inputs,
        "models": models,
        "runtime": {
            "python": platform.python_version(),
            "python_implementation": platform.python_implementation(),
            "platform": platform.platform(),
            "ollama": ollama.version(),
        },
        "options": thresholds["generation_options"],
        "context_probe": context_probe,
    }
    freeze["content_sha256"] = sha256_bytes(canonical_bytes(freeze))
    write_json(output_path, freeze)
    return freeze


def validate_frozen_models(freeze: dict[str, Any], ollama: OllamaClient) -> None:
    installed = ollama.tags()
    for model in freeze.get("models", []):
        current = installed.get(model["tag"])
        if current is None:
            raise ContractError(f"Frozen model is no longer installed: {model['tag']}")
        if current.get("digest") != model.get("digest"):
            raise ContractError(f"Frozen model digest changed: {model['tag']}")
        current_quantization = current.get("details", {}).get("quantization_level")
        if current_quantization != model.get("quantization"):
            raise ContractError(f"Frozen model quantization changed: {model['tag']}")


def validate_frozen_inputs(config_root: Path, freeze_path: Path) -> dict[str, Any]:
    freeze = load_json(freeze_path)
    expected_content_hash = freeze.get("content_sha256")
    unhashed = dict(freeze)
    unhashed.pop("content_sha256", None)
    if expected_content_hash != sha256_bytes(canonical_bytes(unhashed)):
        raise ContractError("Freeze content hash is invalid")
    for relative, expected_hash in freeze.get("inputs", {}).items():
        actual_hash = sha256_file(config_root / relative)
        if actual_hash != expected_hash:
            raise ContractError(f"Frozen input changed: {relative}")
    if sys.version_info[:2] < (3, 12):
        raise ContractError("Python 3.12 or newer is required")
    return freeze
