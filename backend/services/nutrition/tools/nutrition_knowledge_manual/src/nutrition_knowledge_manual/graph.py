from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256


def _candidate(source_revision: str, kind: str, payload: dict[str, Any]) -> dict[str, Any]:
    fingerprint = content_sha256({"source_revision": source_revision, "kind": kind, "payload": payload})
    return {
        "candidate_id": f"cand:{fingerprint[:24]}",
        "candidate_sha256": fingerprint,
        "kind": kind,
        "status": "pending_review",
        "source_revision": source_revision,
        "payload": payload,
    }


def build_candidate_graph(bundle: dict[str, Any], source: dict[str, Any]) -> dict[str, Any]:
    package_key = bundle.get("packageKey")
    if not isinstance(package_key, str) or not package_key:
        raise ManualGraphError("bundle.packageKey is required")
    revision = source["revision_id"]
    candidates: list[dict[str, Any]] = []
    node_ids: set[str] = set()

    def add_node(node_type: str, key: str, properties: dict[str, Any], kind: str) -> str:
        node_id = f"{node_type}:{key}"
        if node_id in node_ids:
            raise ManualGraphError(f"duplicate node id: {node_id}")
        node_ids.add(node_id)
        candidates.append(_candidate(revision, kind, {
            "record_type": "node", "id": node_id, "node_type": node_type, "properties": properties
        }))
        return node_id

    def add_edge(edge_type: str, subject: str, obj: str, properties: dict[str, Any], kind: str) -> None:
        if subject not in node_ids or obj not in node_ids:
            raise ManualGraphError(f"edge endpoint is missing: {subject} -[{edge_type}]-> {obj}")
        candidates.append(_candidate(revision, kind, {
            "record_type": "edge", "edge_type": edge_type, "subject": subject, "object": obj,
            "properties": properties
        }))

    source_node = add_node("source", revision, {
        "source_id": source["source_id"], "revision_id": revision, "title": source.get("title", ""),
        "rights_status": source["rights_status"], "source_sha256": source["sha256"]
    }, "source")
    package_node = add_node("package", package_key, {
        "package_key": package_key, "schema_version": bundle.get("schemaVersion")
    }, "source")
    add_edge("DERIVED_FROM", package_node, source_node, {}, "structural_edge")

    concept_nodes: dict[str, str] = {}
    for concept in sorted(bundle.get("concepts") or [], key=lambda item: item.get("code", "")):
        code = concept.get("code")
        if not isinstance(code, str) or not code:
            raise ManualGraphError("every concept requires a code")
        concept_nodes[code] = add_node("concept", code, {
            "code": code, "kind": concept.get("kind"), "aliases": concept.get("aliases") or [],
            "version": concept.get("version")
        }, "concept")
        add_edge("IN_PACKAGE", concept_nodes[code], package_node, {}, "structural_edge")

    citation_nodes: dict[str, str] = {}
    for citation in sorted(bundle.get("citations") or [], key=lambda item: item.get("id", "")):
        citation_id = citation.get("id")
        if not isinstance(citation_id, str) or not citation_id:
            raise ManualGraphError("every citation requires an id")
        citation_nodes[citation_id] = add_node("citation", citation_id, {
            "citation_id": citation_id, "title": citation.get("title"), "organization": citation.get("organization"),
            "year": citation.get("year"), "locator": citation.get("locator"), "reference": citation.get("reference")
        }, "citation")
        add_edge("IN_PACKAGE", citation_nodes[citation_id], package_node, {}, "structural_edge")

    for version in sorted(bundle.get("recipes") or [], key=lambda item: (item.get("recipeId", ""), item.get("version", 0))):
        recipe_id = version.get("recipeId")
        number = version.get("version")
        payload = version.get("payload") or {}
        recipe_node = add_node("recipe", f"{recipe_id}@{number}", {
            "recipe_id": recipe_id, "version": number, "name": payload.get("name"),
            "meal_type": payload.get("mealType"), "servings": payload.get("servings"),
            "nutrients": payload.get("nutrients") or {}, "allergen_data_complete": payload.get("allergenDataComplete")
        }, "recipe")
        add_edge("IN_PACKAGE", recipe_node, package_node, {}, "structural_edge")
        for ingredient in payload.get("ingredients") or []:
            code = ingredient.get("code")
            target = concept_nodes.get(code)
            if target is None:
                raise ManualGraphError(f"recipe references unknown ingredient concept: {code}")
            add_edge("USES_INGREDIENT", recipe_node, target, {
                "amount": ingredient.get("amount"), "unit": ingredient.get("unit"), "basis": ingredient.get("basis")
            }, "clinical_edge")
        for allergen in payload.get("allergens") or []:
            target = concept_nodes.get(allergen)
            if target is None:
                raise ManualGraphError(f"recipe references unknown allergen concept: {allergen}")
            add_edge("HAS_ALLERGEN", recipe_node, target, {}, "clinical_edge")
        for citation_id in payload.get("sources") or []:
            target = citation_nodes.get(citation_id)
            if target is None:
                raise ManualGraphError(f"recipe references unknown citation: {citation_id}")
            add_edge("SUPPORTED_BY", recipe_node, target, {}, "clinical_edge")

    for version in sorted(bundle.get("rules") or [], key=lambda item: (item.get("ruleId", ""), item.get("version", 0))):
        rule_id = version.get("ruleId")
        number = version.get("version")
        payload = version.get("payload") or {}
        rule_node = add_node("rule", f"{rule_id}@{number}", {
            "rule_id": rule_id, "version": number, "condition_code": payload.get("conditionCode"),
            "daily_maximums": payload.get("dailyMaximums") or {},
            "nutrient_constraints": payload.get("nutrientConstraints") or []
        }, "rule")
        add_edge("IN_PACKAGE", rule_node, package_node, {}, "structural_edge")
        condition = concept_nodes.get(payload.get("conditionCode"))
        if condition is None:
            raise ManualGraphError(f"rule references unknown condition concept: {payload.get('conditionCode')}")
        add_edge("APPLIES_TO", rule_node, condition, {}, "clinical_edge")
        for code in payload.get("excludedIngredients") or []:
            target = concept_nodes.get(code)
            if target is None:
                raise ManualGraphError(f"rule excludes unknown concept: {code}")
            add_edge("EXCLUDES", rule_node, target, {}, "clinical_edge")
        for citation_id in payload.get("sources") or []:
            target = citation_nodes.get(citation_id)
            if target is None:
                raise ManualGraphError(f"rule references unknown citation: {citation_id}")
            add_edge("SUPPORTED_BY", rule_node, target, {}, "clinical_edge")

    candidates.sort(key=lambda item: item["candidate_id"])
    graph = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "mode": "structured_candidates_manual_review_only",
        "source": {
            "source_id": source["source_id"], "revision_id": revision, "sha256": source["sha256"],
            "rights_status": source["rights_status"]
        },
        "package_key": package_key,
        "automatic_admissions": 0,
        "candidate_count": len(candidates),
        "candidates": candidates,
    }
    graph["content_sha256"] = content_sha256({key: value for key, value in graph.items() if key not in {"created_at_utc", "content_sha256"}})
    return graph
