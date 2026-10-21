from __future__ import annotations

from collections import Counter
from pathlib import Path
from typing import Any

from .errors import ContractError
from .fixtures import FixtureCase, load_cases
from .jsonio import load_json
from .manifest import validate_manifest


EXPECTED_GROUPS = {
    "dev": {"negation": 1, "numeric": 2, "table": 1, "alias": 1, "ambiguous": 0, "empty": 1},
    "selection": {"negation": 4, "numeric": 6, "table": 3, "alias": 3, "ambiguous": 2, "empty": 2},
    "holdout": {"negation": 2, "numeric": 3, "table": 2, "alias": 2, "ambiguous": 1, "empty": 2},
}


def validate_contract(module_root: Path, workspace_root: Path) -> dict[str, Any]:
    ontology = load_json(module_root / "config" / "ontology.json")
    _validate_ontology(ontology)
    split_reports: dict[str, Any] = {}
    all_ids: set[str] = set()
    for split in ("dev", "selection", "holdout"):
        cases = load_cases(module_root / "fixtures" / f"{split}.json")
        duplicated = all_ids & {item.case_id for item in cases}
        if duplicated:
            raise ContractError(f"Fixture IDs occur in more than one split: {sorted(duplicated)}")
        all_ids.update(item.case_id for item in cases)
        split_reports[split] = _validate_split(split, cases, ontology)
    records = validate_manifest(module_root / "config" / "source-manifest.json", workspace_root)
    return {
        "valid": True,
        "fixture_count": len(all_ids),
        "splits": split_reports,
        "manifest_source_count": len(records),
        "rights": dict(sorted(Counter(record.rights_status for record in records).items())),
    }


def _validate_ontology(ontology: dict[str, Any]) -> None:
    for key in ("entity_types", "relation_types", "claim_types", "direction_sensitive_relations"):
        values = ontology.get(key)
        if not isinstance(values, list) or len(values) != len(set(values)):
            raise ContractError(f"Ontology {key} must be a unique non-empty list")
    if len(ontology["direction_sensitive_relations"]) < 2:
        raise ContractError("Ontology needs at least two direction-sensitive relation types")
    if not set(ontology["direction_sensitive_relations"]).issubset(ontology["relation_types"]):
        raise ContractError("Direction-sensitive relation is outside the ontology")


def _validate_split(split: str, cases: list[FixtureCase], ontology: dict[str, Any]) -> dict[str, Any]:
    expected = EXPECTED_GROUPS[split]
    actual = Counter(item.primary_group for item in cases)
    if dict(actual) != {key: value for key, value in expected.items() if value}:
        raise ContractError(f"Unexpected group distribution for {split}: {dict(actual)}")
    if any(item.split != split for item in cases):
        raise ContractError(f"A case in {split} declares another split")
    long_count = sum("long" in item.tags for item in cases)
    combined_count = sum("combined" in item.tags for item in cases)
    direction_count = sum(
        1
        for item in cases
        for relation in item.gold["relations"]
        if relation["type"] in ontology["direction_sensitive_relations"]
    )
    minima = {
        "dev": (0, 0, 0),
        "selection": (4, 3, 6),
        "holdout": (2, 1, 3),
    }[split]
    if any(actual_value < minimum for actual_value, minimum in zip(
        (long_count, combined_count, direction_count), minima
    )):
        raise ContractError(
            f"Cross-cutting minima failed for {split}: long={long_count}, "
            f"combined={combined_count}, direction={direction_count}"
        )
    return {
        "case_count": len(cases),
        "groups": dict(sorted(actual.items())),
        "long_count": long_count,
        "combined_count": combined_count,
        "direction_sensitive_relation_count": direction_count,
    }
