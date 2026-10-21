from pathlib import Path
import shutil
import tempfile
import unittest

from nutrition_knowledge_g0.errors import ContractError
from nutrition_knowledge_g0.freeze import create_freeze, validate_frozen_inputs


class FakeOllama:
    def tags(self):
        return {"tiny:test": {"name": "tiny:test", "digest": "abc", "size": 1, "details": {"quantization_level": "Q4", "family": "test"}}}

    def show(self, model):
        return {"capabilities": ["completion"]}

    def version(self):
        return "test"


class FreezeTests(unittest.TestCase):
    def test_frozen_input_mutation_is_rejected(self) -> None:
        module_root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            copied = Path(directory) / "module"
            for relative in (
                "fixtures/dev.json", "fixtures/selection.json", "fixtures/holdout.json",
                "config/ontology.json", "config/extraction.schema.json", "config/manifest.schema.json",
                "config/models.json", "config/prompt.txt", "config/thresholds.json", "config/source-manifest.json",
            ):
                target = copied / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((module_root / relative).read_bytes())
            shutil.copytree(module_root / "src", copied / "src")
            for relative in ("pyproject.toml", "requirements.lock"):
                (copied / relative).write_bytes((module_root / relative).read_bytes())
            freeze_path = Path(directory) / "freeze.json"
            create_freeze(
                config_root=copied,
                output_path=freeze_path,
                model_tags=["tiny:test"],
                ollama=FakeOllama(),
                context_probe={"tiny:test": {"context_valid": True}},
            )
            validate_frozen_inputs(copied, freeze_path)
            (copied / "config" / "prompt.txt").write_text("changed", encoding="utf-8")
            with self.assertRaises(ContractError):
                validate_frozen_inputs(copied, freeze_path)


if __name__ == "__main__":
    unittest.main()
