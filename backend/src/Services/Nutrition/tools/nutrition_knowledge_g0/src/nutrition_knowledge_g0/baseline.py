from __future__ import annotations

from pathlib import Path
from typing import Any

from .fixtures import load_cases
from .jsonio import write_json


def write_manual_baseline(module_root: Path, output_path: Path) -> dict[str, Any]:
    if output_path.exists():
        raise ValueError(f"Refusing to overwrite baseline report: {output_path}")
    cases = load_cases(module_root / "fixtures" / "selection.json")
    report = {
        "schema_version": 1,
        "mode": "keyword_candidate_search_plus_full_manual_review",
        "selection_case_count": len(cases),
        "automatic_graph_admissions": 0,
        "cases_routed_to_manual_review": len(cases),
        "model_selection_candidate": False,
        "note": "Safe fallback when no local extractor passes; manual outcomes are not fabricated as model metrics.",
    }
    write_json(output_path, report)
    return report
