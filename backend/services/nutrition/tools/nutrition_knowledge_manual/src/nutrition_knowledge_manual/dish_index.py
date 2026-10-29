"""Validate the fail-closed dish inventory derived from a frozen book edition."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
from uuid import UUID

from .errors import ManualGraphError
from .jsonio import file_sha256, load_json


_CATEGORIES = {
    "noodle_staple",
    "porridge_medical_feed",
    "main_dish",
    "soup_vegetable",
    "snack_beverage",
}
_ITEM_TYPES = {"dish", "dish_group"}
_NAME_FIDELITY = {"exact", "grouped", "normalized", "descriptive"}
_STATUSES = {
    "candidate",
    "source_located",
    "source_verified",
    "structured",
    "professionally_reviewed",
}
_QUANTITY_STATUSES = {"unknown", "partial", "complete"}
_PROMOTION_DECISIONS = {
    "needs_source_review",
    "needs_quantity_review",
    "needs_split",
    "structured_demo",
    "reference_only_blocked_population",
    "reference_only_blocked_special_need",
    "reference_only_blocked_condition",
}


def validate_dish_index(index: dict, workspace: Path) -> dict:
    """Validate source identity, status progression and catalog links.

    The validator intentionally does not promote a Gemini candidate to a verified
    item. That transition requires source titles, a dated review and evidence from
    the frozen PDF edition.
    """
    workspace = workspace.resolve()
    issues: list[str] = []
    if index.get("schemaVersion") != 1:
        issues.append("schemaVersion must be 1")
    if not _text(index.get("indexKey")):
        issues.append("indexKey is required")
    if index.get("status") != "candidate":
        issues.append("the dish index must remain candidate until professional review")

    source = index.get("source")
    if not isinstance(source, dict):
        issues.append("source must be an object")
        source = {}
    page_count = source.get("pageCount")
    if not isinstance(page_count, int) or page_count < 1:
        issues.append("source.pageCount must be a positive integer")
        page_count = 0
    _check_file(workspace, source.get("path"), source.get("fileSha256"), "source", issues)
    _check_file(workspace, source.get("extractedTextPath"), None, "source.extractedTextPath", issues)

    entries = index.get("entries")
    if not isinstance(entries, list):
        issues.append("entries must be an array")
        entries = []
    expected_count = index.get("expectedEntryCount")
    if expected_count != len(entries):
        issues.append(f"expectedEntryCount {expected_count!r} does not match {len(entries)} entries")
    reference_only_note = index.get("referenceOnlyRecipeNote")
    if not _text(reference_only_note) or "Sách không đề cập công thức" not in reference_only_note:
        issues.append(
            "referenceOnlyRecipeNote must disclose that the book does not provide a cooking recipe"
        )

    ids: set[str] = set()
    names: set[str] = set()
    referenced_recipe_ids: set[str] = set()
    for position, entry in enumerate(entries):
        path = f"entries[{position}]"
        if not isinstance(entry, dict):
            issues.append(f"{path} must be an object")
            continue
        identifier = entry.get("id")
        if not _text(identifier):
            issues.append(f"{path}.id is required")
        elif identifier in ids:
            issues.append(f"{path}.id is duplicated")
        else:
            ids.add(identifier)
        display_name = entry.get("displayName")
        if not _text(display_name):
            issues.append(f"{path}.displayName is required")
        elif display_name.casefold() in names:
            issues.append(f"{path}.displayName is duplicated")
        else:
            names.add(display_name.casefold())
        _choice(entry, "category", _CATEGORIES, path, issues)
        _choice(entry, "itemType", _ITEM_TYPES, path, issues)
        _choice(entry, "nameFidelity", _NAME_FIDELITY, path, issues)
        status = _choice(entry, "verificationStatus", _STATUSES, path, issues)
        quantity_status = _choice(entry, "quantityStatus", _QUANTITY_STATUSES, path, issues)
        promotion = _choice(entry, "promotionDecision", _PROMOTION_DECISIONS, path, issues)

        claimed = _pages(entry.get("pdfPagesClaimed"), page_count, f"{path}.pdfPagesClaimed", issues)
        matched = _pages(entry.get("matchedPdfPages"), page_count, f"{path}.matchedPdfPages", issues)
        if not claimed:
            issues.append(f"{path}.pdfPagesClaimed must not be empty")
        if any(page not in claimed for page in matched):
            issues.append(f"{path}.matchedPdfPages must be a subset of pdfPagesClaimed")

        titles = _strings(entry.get("sourceTitles"), f"{path}.sourceTitles", issues)
        _strings(entry.get("aliases"), f"{path}.aliases", issues)
        contexts = _strings(entry.get("populationContexts"), f"{path}.populationContexts", issues)
        quotes = _strings(entry.get("evidenceQuotes"), f"{path}.evidenceQuotes", issues)
        recipe_ids = _strings(entry.get("recipeVersionIds"), f"{path}.recipeVersionIds", issues)
        for recipe_id in recipe_ids:
            try:
                UUID(recipe_id)
            except ValueError:
                issues.append(f"{path}.recipeVersionIds contains an invalid UUID")
            if recipe_id in referenced_recipe_ids:
                issues.append(f"{path}.recipeVersionIds contains a recipe linked by another entry")
            referenced_recipe_ids.add(recipe_id)

        if status in {"source_located", "source_verified", "structured", "professionally_reviewed"} and not matched:
            issues.append(f"{path}.{status} requires at least one matched PDF page")
        if status in {"source_verified", "structured", "professionally_reviewed"}:
            if not titles:
                issues.append(f"{path}.{status} requires sourceTitles")
            if not quotes:
                issues.append(f"{path}.{status} requires evidenceQuotes")
            if not _text(entry.get("verifiedOn")):
                issues.append(f"{path}.{status} requires verifiedOn")
        if status in {"structured", "professionally_reviewed"} and not recipe_ids:
            issues.append(f"{path}.{status} requires recipeVersionIds")
        if status not in {"structured", "professionally_reviewed"} and recipe_ids:
            issues.append(f"{path}.{status} cannot link recipeVersionIds")
        if not _text(entry.get("reviewNote")):
            issues.append(f"{path}.reviewNote is required")
        if not contexts:
            issues.append(f"{path}.populationContexts must not be empty")
        expected_promotion = {
            "candidate": "needs_source_review",
            "source_located": "needs_quantity_review",
            "structured": "structured_demo",
        }.get(status)
        if expected_promotion is not None and promotion != expected_promotion:
            issues.append(f"{path}.{status} requires promotionDecision={expected_promotion}")
        if quantity_status == "complete" and status not in {
            "source_verified", "structured", "professionally_reviewed"
        }:
            issues.append(f"{path}.quantityStatus=complete requires source verification")

    catalog_recipe_count = _check_catalog(index.get("linkedCatalog"), workspace, referenced_recipe_ids, issues)
    if issues:
        raise ManualGraphError("dish index validation failed: " + "; ".join(issues))

    status_counts = Counter(entry["verificationStatus"] for entry in entries)
    category_counts = Counter(entry["category"] for entry in entries)
    quantity_counts = Counter(entry["quantityStatus"] for entry in entries)
    promotion_counts = Counter(entry["promotionDecision"] for entry in entries)
    return {
        "status": "dish_index_valid",
        "index_key": index["indexKey"],
        "entry_count": len(entries),
        "status_counts": dict(sorted(status_counts.items())),
        "category_counts": dict(sorted(category_counts.items())),
        "quantity_counts": dict(sorted(quantity_counts.items())),
        "promotion_counts": dict(sorted(promotion_counts.items())),
        "linked_catalog_recipe_count": catalog_recipe_count,
        "linked_entry_recipe_count": len(referenced_recipe_ids),
        "reference_only_entry_count": sum(
            1 for entry in entries if isinstance(entry, dict) and not entry.get("recipeVersionIds")
        ),
        "reference_only_recipe_note": reference_only_note,
        "production_publishable": False,
    }


def _check_catalog(value: object, workspace: Path, referenced: set[str], issues: list[str]) -> int:
    if not isinstance(value, dict):
        issues.append("linkedCatalog must be an object")
        return 0
    path = _check_file(workspace, value.get("path"), value.get("fileSha256"), "linkedCatalog", issues)
    if path is None or not path.exists():
        return 0
    catalog = load_json(path)
    if catalog.get("packageKey") != value.get("packageKey"):
        issues.append("linkedCatalog.packageKey does not match the bundle")
    recipes = catalog.get("recipes")
    if not isinstance(recipes, list):
        issues.append("linked catalog recipes must be an array")
        return 0
    actual = {
        recipe.get("payload", {}).get("versionId")
        for recipe in recipes
        if isinstance(recipe, dict) and isinstance(recipe.get("payload"), dict)
    }
    declared = set(_strings(value.get("recipeVersionIds"), "linkedCatalog.recipeVersionIds", issues))
    if actual != declared:
        issues.append("linkedCatalog.recipeVersionIds does not match the bundle")
    if not referenced.issubset(actual):
        issues.append("an entry references a recipe outside the linked catalog")
    return len(actual)


def _check_file(workspace: Path, relative: object, expected_sha256: object,
                label: str, issues: list[str]) -> Path | None:
    if not _text(relative):
        issues.append(f"{label}.path is required")
        return None
    path = (workspace / relative).resolve()
    try:
        path.relative_to(workspace)
    except ValueError:
        issues.append(f"{label}.path escapes the workspace")
        return None
    if not path.is_file():
        issues.append(f"{label}.path does not exist")
        return path
    if expected_sha256 is not None:
        actual = file_sha256(path).upper()
        if not _text(expected_sha256) or actual != expected_sha256.upper():
            issues.append(f"{label}.fileSha256 does not match the file")
    return path


def _choice(entry: dict, key: str, allowed: set[str], path: str, issues: list[str]) -> str | None:
    value = entry.get(key)
    if value not in allowed:
        issues.append(f"{path}.{key} must be one of {sorted(allowed)}")
        return None
    return value


def _pages(value: object, maximum: int, path: str, issues: list[str]) -> list[int]:
    if not isinstance(value, list) or any(not isinstance(page, int) for page in value):
        issues.append(f"{path} must be an integer array")
        return []
    if value != sorted(set(value)):
        issues.append(f"{path} must be sorted and unique")
    if any(page < 1 or page > maximum for page in value):
        issues.append(f"{path} contains a page outside the source")
    return value


def _strings(value: object, path: str, issues: list[str]) -> list[str]:
    if not isinstance(value, list) or any(not _text(item) for item in value):
        issues.append(f"{path} must be a non-empty-string array")
        return []
    if len(value) != len(set(value)):
        issues.append(f"{path} must not contain duplicates")
    return value


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())
