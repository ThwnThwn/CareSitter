from __future__ import annotations

from pathlib import Path
from typing import Any

from .benchmark import probe_context, record_selection, run_holdout, run_selection
from .baseline import write_manual_baseline
from .embedding import run_embedding_smoke
from .errors import GateError
from .freeze import create_freeze, validate_frozen_inputs, validate_frozen_models
from .jsonio import load_json
from .ollama import OllamaClient
from .preflight import run_preflight
from .reporting import build_report
from .validation import validate_contract


class G0Study:
    """Deep local-only seam for preflight, freeze, benchmark and scoring gates."""

    def __init__(
        self,
        module_root: Path | None = None,
        workspace_root: Path | None = None,
        artifact_root: Path | None = None,
        ollama: OllamaClient | None = None,
    ) -> None:
        self.module_root = (module_root or Path(__file__).resolve().parents[2]).resolve()
        self.workspace_root = (workspace_root or self.module_root.parents[4]).resolve()
        self.artifact_root = (
            artifact_root
            or self.workspace_root / "backend" / "artifacts" / "nutrition-knowledge-local"
        ).resolve()
        self.ollama = ollama or OllamaClient()

    def validate(self) -> dict[str, Any]:
        return validate_contract(self.module_root, self.workspace_root)

    def preflight(self) -> dict[str, Any]:
        return run_preflight(self.module_root, self.workspace_root, self.artifact_root)

    def freeze(self, output_path: Path) -> dict[str, Any]:
        output_path = self.require_artifact_path(output_path)
        self.validate()
        preflight_path = self.artifact_root / "preflight.json"
        if not preflight_path.exists() or load_json(preflight_path).get("gate_passed") is not True:
            raise GateError("A passed preflight artifact is required before freezing")
        config = load_json(self.module_root / "config" / "models.json")
        extractor_tags = [item["tag"] for item in config["extractors"]]
        tags = extractor_tags + [config["embedding"]["tag"]]
        installed = self.ollama.tags()
        missing = [tag for tag in tags if tag not in installed]
        if missing:
            raise GateError(f"Pull every exact frozen tag before context probing: {missing}")
        context_probe = probe_context(self.module_root, extractor_tags, self.ollama)
        return create_freeze(
            config_root=self.module_root,
            output_path=output_path,
            model_tags=tags,
            ollama=self.ollama,
            context_probe=context_probe,
        )

    def benchmark_selection(self, freeze_path: Path, model_tag: str) -> dict[str, Any]:
        freeze_path = self.require_artifact_path(freeze_path)
        return run_selection(
            module_root=self.module_root,
            artifact_root=self.artifact_root,
            freeze_path=freeze_path,
            model_tag=model_tag,
            ollama=self.ollama,
        )

    def baseline(self, output_path: Path) -> dict[str, Any]:
        return write_manual_baseline(
            self.module_root,
            self.require_artifact_path(output_path),
        )

    def select_model(self, freeze_path: Path, model_tag: str) -> dict[str, Any]:
        freeze_path = self.require_artifact_path(freeze_path)
        return record_selection(
            module_root=self.module_root,
            artifact_root=self.artifact_root,
            freeze_path=freeze_path,
            model_tag=model_tag,
        )

    def benchmark_holdout(self, freeze_path: Path) -> dict[str, Any]:
        freeze_path = self.require_artifact_path(freeze_path)
        return run_holdout(
            module_root=self.module_root,
            artifact_root=self.artifact_root,
            freeze_path=freeze_path,
            ollama=self.ollama,
        )

    def embedding_smoke(self, freeze_path: Path, output_path: Path) -> dict[str, Any]:
        freeze = validate_frozen_inputs(
            self.module_root,
            self.require_artifact_path(freeze_path),
        )
        validate_frozen_models(freeze, self.ollama)
        addendum = self.artifact_root / "freezes" / f"{freeze['content_sha256']}.selection.json"
        if not addendum.exists():
            raise GateError("Embedding smoke is allowed only after extractor selection is recorded")
        return run_embedding_smoke(
            module_root=self.module_root,
            output_path=self.require_artifact_path(output_path),
            ollama=self.ollama,
        )

    def report(self, freeze_path: Path, preflight_path: Path, output_path: Path) -> dict[str, Any]:
        return build_report(
            module_root=self.module_root,
            artifact_root=self.artifact_root,
            freeze_path=self.require_artifact_path(freeze_path),
            preflight_path=self.require_artifact_path(preflight_path),
            output_path=self.require_artifact_path(output_path),
        )

    def require_artifact_path(self, path: Path) -> Path:
        resolved = path.resolve()
        if not resolved.is_relative_to(self.artifact_root):
            raise ValueError(f"Artifact must stay below {self.artifact_root}: {resolved}")
        return resolved
