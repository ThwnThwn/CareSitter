from __future__ import annotations

from typing import Any


PRIMARY_GROUPS = ("negation", "numeric", "table", "alias", "ambiguous", "empty")


def evaluate_run(split: str, score: dict[str, Any], telemetry: dict[str, Any], thresholds: dict[str, Any]) -> dict[str, Any]:
    target = thresholds[split]
    checks: list[dict[str, Any]] = []

    def minimum(name: str, value: float | int, expected: float | int) -> None:
        checks.append({"name": name, "passed": value >= expected, "actual": value, "expected": f">={expected}"})

    def equal(name: str, value: float | int, expected: float | int) -> None:
        checks.append({"name": name, "passed": value == expected, "actual": value, "expected": expected})

    def maximum(name: str, value: float | int, expected: float | int) -> None:
        checks.append({"name": name, "passed": value <= expected, "actual": value, "expected": f"<={expected}"})

    if split == "selection":
        minimum("schema_valid_cases", telemetry["schema_valid_cases"], target["schema_valid_cases"])
        minimum("semantic_valid_cases", score["semantic_valid_cases"], target["semantic_valid_cases"])
        minimum("entity_precision", score["entity"]["precision"], target["entity_precision"])
        minimum("entity_recall", score["entity"]["recall"], target["entity_recall"])
        minimum("relation_claim_precision", score["relation_claim"]["precision"], target["relation_claim_precision"])
    minimum("entity_f1", score["entity"]["f1"], target["entity_f1"])
    minimum("relation_claim_f1", score["relation_claim"]["f1"], target["relation_claim_f1"])
    equal("context_valid_cases", telemetry["context_valid_cases"], target["context_valid_cases"])
    minimum("negation_safe", score["negation_safe_count"], target["negation_complete"])
    minimum("numeric_value_unit_complete", score["numeric_value_unit_complete"], target["numeric_complete"])
    minimum("empty_complete", score["slices"]["empty"]["complete_count"], target["empty_complete"])
    minimum("evidence_locatable_rate", score["evidence_locatable_rate"], target["evidence_locatable_rate"])
    minimum("admission_precision", score["admission_precision"], target["admission_precision"])
    maximum("latency_p95_seconds", telemetry["latency_p95_seconds"], target["latency_p95_seconds"])
    if split == "selection":
        for group in PRIMARY_GROUPS:
            minimum(f"group_floor_{group}", score["slices"][group]["complete_count"], target["group_floor"])

    hard_pass = all(item["passed"] for item in checks)
    margin = thresholds["engineering_margin"]
    f1_clear = (
        score["entity"]["f1"] >= target["entity_f1"] + margin
        and score["relation_claim"]["f1"] >= target["relation_claim_f1"] + margin
    )
    if not hard_pass:
        decision = "fail"
    elif split == "selection" and not f1_clear:
        decision = "inconclusive"
    else:
        decision = "pass"
    return {"decision": decision, "checks": checks}
