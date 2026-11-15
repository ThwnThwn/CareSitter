from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
from typing import Any

from .errors import ContractError
from .jsonio import load_json


@dataclass(frozen=True)
class Span:
    span_id: str
    text: str
    start: int
    end: int


@dataclass(frozen=True)
class FixtureCase:
    case_id: str
    split: str
    primary_group: str
    tags: tuple[str, ...]
    text: str
    spans: tuple[Span, ...]
    gold: dict[str, list[dict[str, Any]]]


def load_cases(path: Path) -> list[FixtureCase]:
    payload = load_json(path)
    if payload.get("schema_version") != 1 or not isinstance(payload.get("cases"), list):
        raise ContractError(f"Fixture file has an unsupported shape: {path}")
    cases = [_compile_case(item, path) for item in payload["cases"]]
    ids = [item.case_id for item in cases]
    if len(ids) != len(set(ids)):
        raise ContractError(f"Fixture case IDs must be unique: {path}")
    return cases


def validate_prediction_shape(value: Any) -> tuple[bool, str | None]:
    if not isinstance(value, dict) or set(value) != {"entities", "relations", "claims"}:
        return False, "top_level_shape"
    contracts = {
        "entities": {"type", "name", "span_id", "evidence_quote"},
        "relations": {"type", "subject", "object", "span_id", "evidence_quote"},
        "claims": {"type", "subject", "value", "unit", "span_id", "evidence_quote"},
    }
    for collection, keys in contracts.items():
        if not isinstance(value[collection], list):
            return False, f"{collection}_not_array"
        collection_limit = {"entities": 4, "relations": 3, "claims": 3}[collection]
        if len(value[collection]) > collection_limit:
            return False, f"{collection}_too_many_items"
        seen_items: set[tuple[tuple[str, Any], ...]] = set()
        for item in value[collection]:
            if not isinstance(item, dict) or set(item) != keys:
                return False, f"{collection}_item_shape"
            for key in keys - {"value"}:
                if not isinstance(item[key], str) or not item[key].strip():
                    return False, f"{collection}_{key}_invalid"
            for key in keys & {"name", "subject", "object"}:
                if len(item[key]) > 120:
                    return False, f"{collection}_{key}_too_long"
            if len(item["evidence_quote"]) > 96:
                return False, f"{collection}_evidence_quote_too_long"
            if collection == "claims" and len(item["unit"]) > 32:
                return False, "claim_unit_too_long"
            if collection == "claims" and (
                not isinstance(item["value"], (int, float))
                or isinstance(item["value"], bool)
                or not math.isfinite(item["value"])
            ):
                return False, "claim_value_invalid"
            fingerprint = tuple(sorted(item.items()))
            if fingerprint in seen_items:
                return False, f"{collection}_duplicate_item"
            seen_items.add(fingerprint)
    return True, None


def _compile_case(item: dict[str, Any], path: Path) -> FixtureCase:
    required = {"case_id", "split", "primary_group", "tags", "spans", "span_offsets", "gold"}
    if not required.issubset(item):
        raise ContractError(f"Fixture case is missing fields in {path}: {item.get('case_id')}")
    raw_spans = item["spans"]
    if not raw_spans:
        raise ContractError(f"Fixture case has no spans: {item['case_id']}")
    cursor = 0
    text_parts: list[str] = []
    spans: list[Span] = []
    seen_span_ids: set[str] = set()
    for raw_span in raw_spans:
        span_id = raw_span["span_id"]
        span_text = raw_span["text"]
        if span_id in seen_span_ids or not span_text:
            raise ContractError(f"Invalid span in fixture case {item['case_id']}")
        seen_span_ids.add(span_id)
        if text_parts:
            text_parts.append("\n")
            cursor += 1
        start = cursor
        text_parts.append(span_text)
        cursor += len(span_text)
        spans.append(Span(span_id, span_text, start, cursor))
    expected_offsets = [
        {"span_id": span.span_id, "start": span.start, "end": span.end}
        for span in spans
    ]
    if item["span_offsets"] != expected_offsets:
        raise ContractError(f"Raw span offset table is invalid in {item['case_id']}")
    gold = item["gold"]
    for collection in ("entities", "relations", "claims"):
        if not isinstance(gold.get(collection), list):
            raise ContractError(f"Missing gold.{collection} in {item['case_id']}")
        for entry in gold[collection]:
            if entry.get("span_id") not in seen_span_ids:
                raise ContractError(f"Gold item has an unknown span in {item['case_id']}")
    return FixtureCase(
        case_id=item["case_id"],
        split=item["split"],
        primary_group=item["primary_group"],
        tags=tuple(item["tags"]),
        text="".join(text_parts),
        spans=tuple(spans),
        gold=gold,
    )
