from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
import math
import random
from typing import Any, Iterable

from .fixtures import FixtureCase
from .normalization import locate_unique, normalize_key


COLLECTIONS = ("entities", "relations", "claims")


@dataclass(frozen=True)
class Counts:
    true_positive: int = 0
    false_positive: int = 0
    false_negative: int = 0

    def add(self, other: "Counts") -> "Counts":
        return Counts(
            self.true_positive + other.true_positive,
            self.false_positive + other.false_positive,
            self.false_negative + other.false_negative,
        )

    def metrics(self) -> dict[str, float | int]:
        precision_denominator = self.true_positive + self.false_positive
        recall_denominator = self.true_positive + self.false_negative
        precision = self.true_positive / precision_denominator if precision_denominator else 1.0
        recall = self.true_positive / recall_denominator if recall_denominator else 1.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        return {
            "tp": self.true_positive,
            "fp": self.false_positive,
            "fn": self.false_negative,
            "precision": precision,
            "recall": recall,
            "f1": f1,
        }


def score_run(
    cases: Iterable[FixtureCase],
    predictions_by_case: dict[str, dict[str, Any]],
    ontology: dict[str, Any],
) -> dict[str, Any]:
    alias_map = {
        normalize_key(alias): normalize_key(canonical)
        for alias, canonical in ontology.get("aliases", {}).items()
    }
    allowed = {
        "entities": set(ontology["entity_types"]),
        "relations": set(ontology["relation_types"]),
        "claims": set(ontology["claim_types"]),
    }
    totals = {collection: Counts() for collection in COLLECTIONS}
    semantic_valid = 0
    locatable = 0
    predicted_total = 0
    admitted_correct = 0
    per_case: list[dict[str, Any]] = []
    slice_rows: dict[str, list[bool]] = defaultdict(list)
    slice_counts: dict[str, Counts] = defaultdict(Counts)
    negation_safe_count = 0
    numeric_value_unit_complete = 0

    for case in cases:
        prediction_present = case.case_id in predictions_by_case
        prediction = predictions_by_case.get(case.case_id)
        if not prediction_present or prediction is None:
            prediction = {collection: [] for collection in COLLECTIONS}
        spans = {span.span_id: span for span in case.spans}
        case_valid = prediction_present and _semantically_valid(prediction, allowed, spans)
        semantic_valid += int(case_valid)
        case_counts: dict[str, Counts] = {}
        case_locatable = 0
        case_predicted = 0
        case_admitted = 0

        for collection in COLLECTIONS:
            predicted_items = prediction.get(collection, []) if isinstance(prediction, dict) else []
            gold_items = case.gold[collection]
            predicted_keys = [_item_key(collection, item, alias_map) for item in predicted_items]
            gold_keys = [_item_key(collection, item, alias_map) for item in gold_items]
            counts = _counter_counts(predicted_keys, gold_keys)
            case_counts[collection] = counts
            totals[collection] = totals[collection].add(counts)

            remaining_gold = Counter(
                (_item_key(collection, item, alias_map), item["span_id"])
                for item in gold_items
            )
            for item, key in zip(predicted_items, predicted_keys):
                case_predicted += 1
                span = spans.get(item.get("span_id"))
                evidence = item.get("evidence_quote")
                item_locatable = bool(
                    span
                    and isinstance(evidence, str)
                    and locate_unique(span.text, evidence) is not None
                )
                if not item_locatable:
                    continue
                case_locatable += 1
                gold_locator = (key, item["span_id"])
                if remaining_gold[gold_locator] > 0:
                    remaining_gold[gold_locator] -= 1
                    case_admitted += 1

        relation_claim_counts = case_counts["relations"].add(case_counts["claims"])
        all_item_counts = case_counts["entities"].add(relation_claim_counts)
        complete = all(
            counts.false_positive == 0 and counts.false_negative == 0
            for counts in case_counts.values()
        )
        per_case.append({
            "case_id": case.case_id,
            "primary_group": case.primary_group,
            "tags": list(case.tags),
            "semantic_valid": case_valid,
            "complete": complete,
            "entity": case_counts["entities"].metrics(),
            "relation_claim": relation_claim_counts.metrics(),
            "all_items": all_item_counts.metrics(),
            "locatable": case_locatable,
            "predicted": case_predicted,
            "admitted_correct": case_admitted,
        })
        for slice_name in {case.primary_group, *case.tags}:
            slice_rows[slice_name].append(complete)
            slice_counts[slice_name] = slice_counts[slice_name].add(all_item_counts)
        if case.primary_group == "negation" and relation_claim_counts.false_positive == 0:
            negation_safe_count += 1
        if case.primary_group == "numeric" and (
            case_counts["claims"].false_positive == 0
            and case_counts["claims"].false_negative == 0
        ):
            numeric_value_unit_complete += 1
        locatable += case_locatable
        predicted_total += case_predicted
        admitted_correct += case_admitted

    entity_metrics = totals["entities"].metrics()
    relation_claim_metrics = totals["relations"].add(totals["claims"]).metrics()
    return {
        "case_count": len(per_case),
        "semantic_valid_cases": semantic_valid,
        "entity": entity_metrics,
        "relation_claim": relation_claim_metrics,
        "evidence_locatable_rate": locatable / predicted_total if predicted_total else 1.0,
        "evidence_locatable_count": locatable,
        "evidence_unlocatable_count": predicted_total - locatable,
        "admission_precision": admitted_correct / locatable if locatable else (1.0 if predicted_total == 0 else 0.0),
        "negation_safe_count": negation_safe_count,
        "numeric_value_unit_complete": numeric_value_unit_complete,
        "slices": {
            name: {
                "case_count": len(values),
                "complete_count": sum(values),
                "items": slice_counts[name].metrics(),
            }
            for name, values in sorted(slice_rows.items())
        },
        "cases": per_case,
    }


def compare_runs(first: dict[str, dict[str, Any]], second: dict[str, dict[str, Any]]) -> dict[str, Any]:
    case_ids = sorted(set(first) | set(second))
    disagreements = 0
    jaccards: list[float] = []
    for case_id in case_ids:
        first_items = _flat_prediction_keys(first.get(case_id, {}))
        second_items = _flat_prediction_keys(second.get(case_id, {}))
        if first_items != second_items:
            disagreements += 1
        union = first_items | second_items
        jaccards.append(len(first_items & second_items) / len(union) if union else 1.0)
    return {
        "case_count": len(case_ids),
        "disagreement_case_count": disagreements,
        "disagreement_rate": disagreements / len(case_ids) if case_ids else 0.0,
        "mean_item_jaccard": sum(jaccards) / len(jaccards) if jaccards else 1.0,
    }


def bootstrap_case_pairs(
    cases: list[FixtureCase],
    first: dict[str, dict[str, Any]],
    second: dict[str, dict[str, Any]],
    ontology: dict[str, Any],
    *,
    iterations: int = 1000,
    seed: int = 20261020,
) -> dict[str, Any]:
    """Describe case-sampling noise without treating two runs as independent cases."""

    if not cases:
        return {"iterations": 0, "note": "no cases"}
    randomizer = random.Random(seed)
    samples: dict[str, list[float]] = {
        "run_1_entity_f1": [],
        "run_1_relation_claim_f1": [],
        "run_2_entity_f1": [],
        "run_2_relation_claim_f1": [],
    }
    for _ in range(iterations):
        selected = [randomizer.choice(cases) for _ in cases]
        first_score = score_run(selected, first, ontology)
        second_score = score_run(selected, second, ontology)
        samples["run_1_entity_f1"].append(float(first_score["entity"]["f1"]))
        samples["run_1_relation_claim_f1"].append(float(first_score["relation_claim"]["f1"]))
        samples["run_2_entity_f1"].append(float(second_score["entity"]["f1"]))
        samples["run_2_relation_claim_f1"].append(float(second_score["relation_claim"]["f1"]))
    return {
        "iterations": iterations,
        "unit": "case_id with both model runs retained",
        "interpretation": "descriptive only; not an acceptance gate",
        "intervals": {
            name: {"p2_5": percentile(values, 0.025), "p50": percentile(values, 0.5), "p97_5": percentile(values, 0.975)}
            for name, values in samples.items()
        },
    }


def percentile(values: list[float], percentile_value: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    rank = math.ceil(percentile_value * len(ordered)) - 1
    return ordered[max(0, min(rank, len(ordered) - 1))]


def _counter_counts(predicted: list[tuple[Any, ...]], gold: list[tuple[Any, ...]]) -> Counts:
    predicted_counter = Counter(predicted)
    gold_counter = Counter(gold)
    matches = sum((predicted_counter & gold_counter).values())
    return Counts(matches, len(predicted) - matches, len(gold) - matches)


def _item_key(collection: str, item: dict[str, Any], aliases: dict[str, str]) -> tuple[Any, ...]:
    item_type = item.get("type")
    if collection == "entities":
        return item_type, _canonical_name(item.get("name"), aliases)
    if collection == "relations":
        return (
            item_type,
            _canonical_name(item.get("subject"), aliases),
            _canonical_name(item.get("object"), aliases),
        )
    return (
        item_type,
        _canonical_name(item.get("subject"), aliases),
        _decimal_key(item.get("value")),
        normalize_key(str(item.get("unit", ""))),
    )


def _canonical_name(value: Any, aliases: dict[str, str]) -> str:
    key = normalize_key(str(value or ""))
    return aliases.get(key, key)


def _decimal_key(value: Any) -> str:
    try:
        normalized = Decimal(str(value)).normalize()
        return format(normalized, "f")
    except (InvalidOperation, ValueError):
        return str(value)


def _semantically_valid(
    prediction: dict[str, Any],
    allowed: dict[str, set[str]],
    spans: dict[str, Any],
) -> bool:
    if not isinstance(prediction, dict):
        return False
    for collection in COLLECTIONS:
        if not isinstance(prediction.get(collection), list):
            return False
        for item in prediction[collection]:
            if not isinstance(item, dict):
                return False
            if item.get("type") not in allowed[collection] or item.get("span_id") not in spans:
                return False
    entity_names = {normalize_key(item.get("name", "")) for item in prediction["entities"]}
    for relation in prediction["relations"]:
        if normalize_key(relation.get("subject", "")) not in entity_names:
            return False
        if normalize_key(relation.get("object", "")) not in entity_names:
            return False
    for claim in prediction["claims"]:
        if normalize_key(claim.get("subject", "")) not in entity_names:
            return False
    return True


def _flat_prediction_keys(prediction: dict[str, Any]) -> set[str]:
    flattened: set[str] = set()
    for collection in COLLECTIONS:
        for item in prediction.get(collection, []):
            flattened.add(f"{collection}:{repr(sorted(item.items()))}")
    return flattened
