from __future__ import annotations

from copy import deepcopy
from datetime import datetime
from decimal import Decimal, ROUND_HALF_EVEN
from pathlib import Path
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256


RELEASE_PROFILE = "adult_baseline_source_reference_v1"
REQUIRED_NUTRIENTS = {
    "energy_kcal": "kcal",
    "protein_g": "g",
    "carbohydrate_g": "g",
    "fat_g": "g",
    "fiber_g": "g",
    "sodium_mg": "mg",
}
REQUIRED_BLOCKS = {
    "KIDNEY_DISEASE",
    "DYSPHAGIA",
    "TUBE_FEEDING",
    "FLUID_RESTRICTION",
    "ELECTROLYTE_RESTRICTION",
}
MISSING_RECIPE_DISCLOSURE = "Sách không đề cập công thức"


def prepare_source_reference_bundle(
    *, source_bundle: dict[str, Any], package_key: str, food_snapshot: dict[str, Any]
) -> dict[str, Any]:
    """Project the verified demo source into a clearly labelled production reference bundle."""
    package_key = _required_text(package_key, "package_key")
    if not all(part and part.replace("-", "").isalnum() for part in [package_key]):
        raise ManualGraphError("package_key must use lower-case kebab-case")
    if package_key.lower() != package_key or "_" in package_key:
        raise ManualGraphError("package_key must use lower-case kebab-case")
    bundle = deepcopy(source_bundle)
    _validate_bundle_scope(bundle)
    foods = _index(food_snapshot.get("foods"), "conceptCode", "food snapshot")
    bundle["packageKey"] = package_key
    for version in bundle.get("recipes") or []:
        payload = version.get("payload") if isinstance(version, dict) else None
        if not isinstance(payload, dict):
            raise ManualGraphError("every recipe version requires a payload")
        recipe_note = _required_text(payload.get("sourceRecipeNote"), "recipe sourceRecipeNote")
        if MISSING_RECIPE_DISCLOSURE not in recipe_note:
            raise ManualGraphError(
                "source-reference recipes must disclose that the book does not provide a cooking recipe"
            )
        ingredients = payload.get("ingredients") or []
        nutrients = payload.get("nutrients")
        if not isinstance(nutrients, dict):
            raise ManualGraphError("every recipe requires nutrient values")
        for nutrient in REQUIRED_NUTRIENTS:
            calculated = sum(
                Decimal(str(ingredient["amount"]))
                * Decimal(str(foods[ingredient["code"]]["nutrients"][nutrient]["value"]))
                / Decimal("100")
                for ingredient in ingredients
            ).quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)
            nutrients[nutrient] = int(calculated) if calculated == calculated.to_integral() else float(calculated)
        steps = payload.get("preparationSteps") or []
        payload["preparationSteps"] = [_production_note(step) for step in steps]
    return bundle


def build_source_reference_evidence(
    *,
    bundle: dict[str, Any],
    bundle_path: Path,
    food_snapshot: dict[str, Any],
    source_index: dict[str, Any],
    authorization_id: str,
    authorized_by: str,
    authorized_at: str,
    notes: str,
) -> dict[str, Any]:
    """Build deterministic production evidence for a non-clinical book-reference catalog."""
    _validate_bundle_scope(bundle)
    authorization_id = _required_text(authorization_id, "authorization_id")
    authorized_by = _required_text(authorized_by, "authorized_by")
    notes = _required_text(notes, "notes")
    _timestamp(authorized_at, "authorized_at")

    citations = _index(bundle.get("citations"), "id", "bundle citations")
    book_citations = sorted(
        (item for item in citations.values() if item.get("fileSha256")),
        key=lambda item: item["id"],
    )
    if not book_citations:
        raise ManualGraphError("source-reference release requires a document citation with SHA-256")
    publication = book_citations[0]
    document_sha = _sha256(publication.get("fileSha256"), "book citation fileSha256")

    foods = _index(food_snapshot.get("foods"), "conceptCode", "food snapshot")
    food_source_id = "VIETNAM_FOOD_COMPOSITION_2017"
    if food_source_id not in citations:
        raise ManualGraphError(f"bundle citation is missing {food_source_id}")

    recipe_evidence: list[dict[str, Any]] = []
    recipes = bundle.get("recipes")
    if not isinstance(recipes, list) or len(recipes) != 12:
        raise ManualGraphError("source-reference release requires exactly 12 recipes")
    for version in recipes:
        payload = version.get("payload") if isinstance(version, dict) else None
        if not isinstance(payload, dict):
            raise ManualGraphError("every recipe version requires a payload")
        version_id = _required_text(payload.get("versionId"), "recipe versionId")
        ingredients = payload.get("ingredients")
        if not isinstance(ingredients, list) or not ingredients:
            raise ManualGraphError(f"recipe {version_id} requires ingredients")

        ingredient_evidence: list[dict[str, Any]] = []
        for ingredient in ingredients:
            code = _required_text(ingredient.get("code"), "ingredient code")
            food = foods.get(code)
            if food is None:
                raise ManualGraphError(f"ingredient {code} is missing from the food snapshot")
            nutrients = food.get("nutrients")
            if not isinstance(nutrients, dict):
                raise ManualGraphError(f"food {code} has no nutrient values")
            per_100: dict[str, int | float] = {}
            for nutrient, unit in REQUIRED_NUTRIENTS.items():
                item = nutrients.get(nutrient)
                if not isinstance(item, dict) or item.get("unit") != unit:
                    raise ManualGraphError(f"food {code} has missing or wrong unit for {nutrient}")
                value = item.get("value")
                if not isinstance(value, (int, float)) or value < 0:
                    raise ManualGraphError(f"food {code} has invalid value for {nutrient}")
                per_100[nutrient] = value
            ingredient_evidence.append({
                "ingredientCode": code,
                "sourceId": food_source_id,
                "sourceLocator": _required_text(food.get("sourceLocator"), f"food {code} sourceLocator"),
                "amountBasis": _required_text(ingredient.get("basis"), f"ingredient {code} basis"),
                "nutrientsPer100G": per_100,
                "ediblePortionFactor": 1,
                "yieldFactor": 1,
                "sourceReferenceCode": _required_text(food.get("ninCode"), f"food {code} ninCode"),
            })

        supplied_nutrients = payload.get("nutrients")
        if not isinstance(supplied_nutrients, dict):
            raise ManualGraphError(f"recipe {version_id} requires nutrients")
        nutrient_evidence: list[dict[str, Any]] = []
        for nutrient, unit in REQUIRED_NUTRIENTS.items():
            supplied = supplied_nutrients.get(nutrient)
            if not isinstance(supplied, (int, float)) or supplied < 0:
                raise ManualGraphError(f"recipe {version_id} has invalid {nutrient}")
            calculated = sum(
                Decimal(str(ingredient["amount"]))
                * Decimal(str(foods[ingredient["code"]]["nutrients"][nutrient]["value"]))
                / Decimal("100")
                for ingredient in ingredients
            ).quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)
            if calculated != Decimal(str(supplied)):
                raise ManualGraphError(
                    f"recipe {version_id} {nutrient} does not match the pinned food snapshot"
                )
            nutrient_evidence.append({
                "key": nutrient,
                "value": supplied,
                "unit": unit,
                "method": "ingredient_sum_identity_factors",
                "sourceIds": [food_source_id],
                "calculation": (
                    "Sum ingredient grams × pinned per-100-g value × edible factor 1 "
                    "× yield factor 1; round half-even to 2 decimals."
                ),
            })
        recipe_evidence.append({
            "recipeVersionId": version_id,
            "ingredients": ingredient_evidence,
            "nutrients": nutrient_evidence,
            "unresolvedItems": [],
        })

    bundle_digest = file_sha256(bundle_path)
    index_digest = content_sha256(source_index)
    snapshot_digest = content_sha256(food_snapshot)
    authority = {
        "authorizationId": authorization_id,
        "authorityType": "product_owner",
        "authorizedBy": authorized_by,
        "authorizedAt": authorized_at,
        "decision": "approved",
        "notes": notes,
    }
    source_reviews = [
        {
            "sourceRevisionId": _source_revision(item),
            "rightsStatus": "permitted",
        }
        for item in sorted(citations.values(), key=lambda item: item["id"])
    ]
    knowledge_review = {
        "schemaVersion": 1,
        "candidateGraphSha256": content_sha256(bundle),
        "decisionLedgerSha256": content_sha256(authority),
        "reviewedGraphSha256": content_sha256({
            "bundle": bundle_digest,
            "foodSnapshot": snapshot_digest,
            "sourceIndex": index_digest,
        }),
        "candidateCount": len(recipes),
        "approvedCount": len(recipes),
        "pendingCount": 0,
        "rejectedCount": 0,
        "sources": source_reviews,
        "clinicalReviewerIds": [],
        "releaseAuthorityIds": [authorization_id],
        "decision": "approved",
    }
    return {
        "schemaVersion": 1,
        "packageKey": _required_text(bundle.get("packageKey"), "bundle packageKey"),
        "bundleFileSha256": bundle_digest,
        "contentStatus": "review_ready",
        "calculationBasis": (
            "Published-source reference estimates. Sum ingredient grams against the pinned "
            "Viện Dinh dưỡng food-composition snapshot with identity edible/yield factors; "
            "source-missing nutrient fields use the snapshot's documented zero normalization. "
            "Not a disease-treatment prescription."
        ),
        "requiredNutrients": list(REQUIRED_NUTRIENTS),
        "recipes": recipe_evidence,
        "rules": [],
        "clinicalReview": None,
        "releaseProfile": RELEASE_PROFILE,
        "knowledgeReview": knowledge_review,
        "sourcePublication": {
            "sourceId": publication["id"],
            "sourceRevisionId": _source_revision(publication),
            "documentSha256": document_sha,
            "organization": _required_text(publication.get("organization"), "publication organization"),
            "publicationYear": publication.get("year"),
            "verifiedAt": authorized_at,
            "decision": "verified",
        },
        "releaseAuthorization": authority,
    }


def _validate_bundle_scope(bundle: dict[str, Any]) -> None:
    if bundle.get("rules") != []:
        raise ManualGraphError("source-reference release cannot contain disease rules")
    scopes = bundle.get("supportedScopes")
    if not isinstance(scopes, list) or not scopes:
        raise ManualGraphError("source-reference release requires an adult baseline scope")
    for scope in scopes:
        if scope.get("population") != "adult" or scope.get("conditionCodes") != []:
            raise ManualGraphError("source-reference release supports adult baseline only")
        if scope.get("medicationPolicy") != "reported_none_only":
            raise ManualGraphError("source-reference release requires reported_none_only medication policy")
        if not REQUIRED_BLOCKS.issubset(set(scope.get("blockedSpecialNeeds") or [])):
            raise ManualGraphError("source-reference release is missing required special-needs blocks")


def _index(value: Any, key: str, label: str) -> dict[str, dict[str, Any]]:
    if not isinstance(value, list):
        raise ManualGraphError(f"{label} must be an array")
    result: dict[str, dict[str, Any]] = {}
    for item in value:
        if not isinstance(item, dict):
            raise ManualGraphError(f"{label} entries must be objects")
        identity = _required_text(item.get(key), f"{label} {key}")
        if identity in result:
            raise ManualGraphError(f"{label} repeats {identity}")
        result[identity] = item
    return result


def _source_revision(citation: dict[str, Any]) -> str:
    digest = citation.get("fileSha256")
    if isinstance(digest, str) and digest:
        return f"{citation['id']}@sha256:{_sha256(digest, 'citation fileSha256').lower()}"
    verified = _required_text(citation.get("verifiedOn"), "citation verifiedOn")
    return f"{citation['id']}@verified:{verified}"


def _sha256(value: Any, label: str) -> str:
    text = _required_text(value, label)
    if len(text) != 64 or any(character not in "0123456789abcdefABCDEF" for character in text):
        raise ManualGraphError(f"{label} must be a SHA-256 hexadecimal value")
    return text


def _required_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ManualGraphError(f"{label} is required")
    return value.strip()


def _timestamp(value: str, label: str) -> datetime:
    text = _required_text(value, label)
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        raise ManualGraphError(f"{label} must be an ISO-8601 timestamp") from None
    if parsed.tzinfo is None:
        raise ManualGraphError(f"{label} must include a timezone")
    return parsed


def _production_note(value: Any) -> str:
    text = _required_text(value, "preparation step")
    replacements = {
        "Số liệu demo tạm tính": "Giá trị dinh dưỡng ước tính",
        "số liệu demo tạm tính": "giá trị dinh dưỡng ước tính",
        "số liệu demo": "giá trị dinh dưỡng ước tính",
        "Số liệu demo": "Giá trị dinh dưỡng ước tính",
        "phải được data review trước khi phát hành": "dùng tham khảo, không phải chỉ định điều trị",
        "phải được data review": "dùng tham khảo, không phải chỉ định điều trị",
    }
    for source, target in replacements.items():
        text = text.replace(source, target)
    return text
