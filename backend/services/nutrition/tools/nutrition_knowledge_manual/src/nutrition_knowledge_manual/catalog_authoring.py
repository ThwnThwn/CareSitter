from __future__ import annotations

from copy import deepcopy
from datetime import datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN
from itertools import product
import re
from typing import Any
from urllib.parse import urlsplit
from uuid import UUID

from .errors import ManualGraphError
from .jsonio import content_sha256, serialized_json_sha256
from .catalog_review import validate_catalog_review_ledger


SUPPORTED_MEAL_TYPES = ("breakfast", "lunch", "dinner")
SUPPORTED_DIETARY_PATTERNS = {"vegetarian"}
SUPPORTED_RELEASE_PROFILE = "adult_baseline_v1"
DECIMAL_PLACES = Decimal("0.01")


def prepare_catalog_candidate(
    *,
    profile: dict[str, Any],
    draft: dict[str, Any],
    food_snapshot: dict[str, Any],
    input_file_sha256: dict[str, str],
) -> dict[str, dict[str, Any]]:
    """Build deterministic, review-only catalog artifacts without external I/O."""
    _validate_profile(profile, require_authoring=True)
    _validate_input_bindings(profile, input_file_sha256)

    package_key = _required_text(profile, "package_key")
    food_source_id = _required_text(profile, "food_source_id")
    food_reference_code_field = _required_text(profile, "food_reference_code_field")
    nutrient_units = _required_nutrient_units(profile)
    expected_counts = _expected_recipe_counts(profile)
    scope = _baseline_scope(profile)
    factor_policy = _factor_policy(profile)
    allergen_map = _allergen_map(profile)
    default_unresolved_items = _default_unresolved_items(profile)
    rule_policy = profile.get("source_rule_policy", "reject")

    source_schema_version = draft.get("schemaVersion")
    if source_schema_version not in {1, 2}:
        raise ManualGraphError("catalog authoring requires a schemaVersion=1 or schemaVersion=2 draft")
    source_rules = draft.get("rules") or []
    if not isinstance(source_rules, list):
        raise ManualGraphError("draft rules must be an array")
    if source_rules and rule_policy == "reject":
        raise ManualGraphError("adult baseline authoring forbids disease rules")
    if rule_policy not in {"reject", "omit_for_baseline"}:
        raise ManualGraphError("source_rule_policy must be reject or omit_for_baseline")

    citations = _unique_by(draft.get("citations"), "id", "draft citations")
    if food_source_id not in citations:
        raise ManualGraphError(f"food source citation {food_source_id} is missing from the draft")
    concepts = _unique_by(draft.get("concepts"), "code", "draft concepts")
    foods = _food_index(food_snapshot, nutrient_units, food_reference_code_field)

    recipes = draft.get("recipes")
    if not isinstance(recipes, list):
        raise ManualGraphError("draft recipes must be an array")
    _validate_meal_counts(recipes, expected_counts)

    recipe_ids: set[str] = set()
    version_ids: set[str] = set()
    candidate_recipes: list[dict[str, Any]] = []
    recipe_evidence: list[dict[str, Any]] = []
    recipe_cards: list[dict[str, Any]] = []
    used_codes: set[str] = set()
    used_citations: set[str] = {food_source_id}

    for recipe in recipes:
        candidate, evidence, card = _prepare_recipe(
            recipe=recipe,
            foods=foods,
            concepts=concepts,
            citations=citations,
            food_source_id=food_source_id,
            food_reference_code_field=food_reference_code_field,
            nutrient_units=nutrient_units,
            factor_policy=factor_policy,
            allergen_map=allergen_map,
            default_unresolved_items=default_unresolved_items,
        )
        recipe_id = _required_uuid(candidate, "recipeId")
        version_id = _required_uuid(candidate["payload"], "versionId")
        if recipe_id in recipe_ids:
            raise ManualGraphError(f"duplicate recipeId: {recipe_id}")
        if version_id in version_ids:
            raise ManualGraphError(f"duplicate recipe versionId: {version_id}")
        recipe_ids.add(recipe_id)
        version_ids.add(version_id)
        used_codes.update(item["code"] for item in candidate["payload"]["ingredients"])
        used_codes.update(candidate["payload"]["allergens"])
        used_citations.update(candidate["payload"]["sources"])
        digest = content_sha256({"recipe": candidate, "evidence": evidence})
        card["candidate_sha256"] = digest
        candidate_recipes.append(candidate)
        recipe_evidence.append(evidence)
        recipe_cards.append(card)

    missing_concepts = sorted(code for code in used_codes if code not in concepts)
    if missing_concepts:
        raise ManualGraphError(f"catalog concepts are missing codes: {', '.join(missing_concepts)}")
    unknown_citations = sorted(source for source in used_citations if source not in citations)
    if unknown_citations:
        raise ManualGraphError(f"catalog citations are missing ids: {', '.join(unknown_citations)}")

    bundle = {
        "schemaVersion": 2,
        "packageKey": package_key,
        "supportedScopes": [scope],
        "citations": [deepcopy(citations[key]) for key in sorted(used_citations)],
        "concepts": [deepcopy(concepts[key]) for key in sorted(used_codes)],
        "recipes": candidate_recipes,
        "rules": [],
    }
    bundle_file_sha256 = serialized_json_sha256(bundle)
    evidence = {
        "schemaVersion": 1,
        "packageKey": package_key,
        "bundleFileSha256": bundle_file_sha256,
        "contentStatus": "technical_draft",
        "calculationBasis": _calculation_basis(factor_policy),
        "requiredNutrients": list(nutrient_units),
        "recipes": recipe_evidence,
        "rules": [],
        "clinicalReview": None,
        "releaseProfile": SUPPORTED_RELEASE_PROFILE,
    }
    coverage = _combination_coverage(candidate_recipes, nutrient_units, profile.get("daily_targets") or {})
    review_packet = {
        "schema_version": 1,
        "profile_id": _required_text(profile, "profile_id"),
        "profile_content_sha256": content_sha256(profile),
        "package_key": package_key,
        "product_semantics": _required_text(profile, "product_semantics"),
        "recipe_cards": recipe_cards,
        "combination_coverage": coverage,
        "source_projection": {
            "source_schema_version": source_schema_version,
            "output_schema_version": 2,
            "rule_policy": rule_policy,
            "source_rule_count": len(source_rules),
            "output_rule_count": 0,
            "omitted_rule_count": len(source_rules),
        },
        "review_requirements": {
            "data_roles": ["data_steward"],
            "clinical_roles": ["dietitian", "physician"],
            "all_recipe_candidates_require_both_reviews": True,
        },
    }
    manifest_without_hash = {
        "schema_version": 1,
        "profile_id": _required_text(profile, "profile_id"),
        "profile_content_sha256": content_sha256(profile),
        "package_key": package_key,
        "status": "candidate_review_required",
        "release_enabled": bool(profile.get("release_enabled")),
        "source_projection": deepcopy(review_packet["source_projection"]),
        "input_file_sha256": dict(sorted(input_file_sha256.items())),
        "artifacts": {
            "candidate_bundle": _artifact_digest(bundle),
            "candidate_evidence": _artifact_digest(evidence),
            "review_packet": _artifact_digest(review_packet),
        },
        "recipe_candidates": [
            {
                "recipe_version_id": card["recipe_version_id"],
                "candidate_sha256": card["candidate_sha256"],
            }
            for card in recipe_cards
        ],
    }
    manifest = {**manifest_without_hash, "content_sha256": content_sha256(manifest_without_hash)}
    return {
        "bundle": bundle,
        "evidence": evidence,
        "review_packet": review_packet,
        "manifest": manifest,
    }


def finalize_catalog_candidate(
    *,
    profile: dict[str, Any],
    candidate_manifest: dict[str, Any],
    candidate_bundle: dict[str, Any],
    candidate_evidence: dict[str, Any],
    decisions: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Finalize reviewed artifacts; knowledge review remains a separate mandatory gate."""
    _validate_profile(profile, require_authoring=False)
    if not profile.get("release_enabled"):
        raise ManualGraphError("catalog finalization is disabled for this profile")
    _validate_manifest(candidate_manifest, candidate_bundle, candidate_evidence, profile)

    expected_manifest_hash = _required_text(candidate_manifest, "content_sha256")
    validate_catalog_review_ledger(candidate_manifest, decisions)
    if decisions.get("candidate_manifest_sha256") != expected_manifest_hash:
        raise ManualGraphError("decision ledger is not bound to the candidate manifest")

    manifest_candidates = _unique_by(
        candidate_manifest.get("recipe_candidates"), "recipe_version_id", "manifest recipe candidates"
    )
    decision_by_recipe = _unique_by(decisions.get("decisions"), "recipe_version_id", "recipe decisions")
    if set(manifest_candidates) != set(decision_by_recipe):
        raise ManualGraphError("every recipe candidate requires exactly one decision")

    recipe_by_version = {
        _required_text(item["payload"], "versionId"): item
        for item in candidate_bundle.get("recipes") or []
    }
    evidence_by_version = _unique_by(
        candidate_evidence.get("recipes"), "recipeVersionId", "candidate recipe evidence"
    )
    clinical_reviewer_ids: set[str] = set()
    finalized_evidence: list[dict[str, Any]] = []

    for version_id in sorted(manifest_candidates):
        if version_id not in recipe_by_version or version_id not in evidence_by_version:
            raise ManualGraphError(f"candidate artifacts are missing recipe version {version_id}")
        evidence = evidence_by_version[version_id]
        expected_candidate_hash = content_sha256({
            "recipe": recipe_by_version[version_id], "evidence": evidence
        })
        manifest_hash = manifest_candidates[version_id].get("candidate_sha256")
        decision = decision_by_recipe[version_id]
        if manifest_hash != expected_candidate_hash or decision.get("candidate_sha256") != expected_candidate_hash:
            raise ManualGraphError(f"recipe decision is stale or tampered: {version_id}")
        _validate_approval(decision.get("data_review"), {"data_steward"}, "data", version_id)
        clinical = _validate_approval(
            decision.get("clinical_review"), {"dietitian", "physician"}, "clinical", version_id
        )
        clinical_reviewer_ids.add(clinical["reviewer_id"])
        _validate_resolutions(
            evidence.get("unresolvedItems") or [], decision.get("resolutions") or [], decision, version_id
        )
        finalized_evidence.append({**deepcopy(evidence), "unresolvedItems": []})

    clinical_review = decisions.get("clinical_review")
    if not isinstance(clinical_review, dict) or clinical_review.get("decision") != "approved":
        raise ManualGraphError("an approved final clinical review is required")
    clinical_reviewer_id = _required_text(clinical_review, "reviewerId")
    if clinical_reviewer_id not in clinical_reviewer_ids:
        raise ManualGraphError("final clinical reviewer must appear in recipe clinical decisions")
    for field in ("reviewerName", "credentials", "reviewedAt"):
        _required_text(clinical_review, field)
    try:
        reviewed_at = datetime.fromisoformat(clinical_review["reviewedAt"])
    except ValueError:
        raise ManualGraphError("clinical review reviewedAt must be an ISO-8601 timestamp") from None
    if reviewed_at.tzinfo is None:
        raise ManualGraphError("clinical review reviewedAt must include a timezone")

    release_bundle = deepcopy(candidate_bundle)
    release_evidence = {
        **deepcopy(candidate_evidence),
        "contentStatus": "review_ready",
        "recipes": finalized_evidence,
        "clinicalReview": deepcopy(clinical_review),
    }
    release_manifest_without_hash = {
        "schema_version": 1,
        "profile_id": _required_text(profile, "profile_id"),
        "package_key": _required_text(profile, "package_key"),
        "candidate_manifest_sha256": expected_manifest_hash,
        "decision_ledger_sha256": decisions["content_sha256"],
        "status": "knowledge_review_required",
        "clinical_reviewer_ids": sorted(clinical_reviewer_ids),
        "artifacts": {
            "release_bundle": _artifact_digest(release_bundle),
            "release_evidence": _artifact_digest(release_evidence),
        },
    }
    release_manifest = {
        **release_manifest_without_hash,
        "content_sha256": content_sha256(release_manifest_without_hash),
    }
    return {
        "bundle": release_bundle,
        "evidence": release_evidence,
        "manifest": release_manifest,
    }


def _prepare_recipe(
    *, recipe: dict[str, Any], foods: dict[str, dict[str, Any]], concepts: dict[str, dict[str, Any]],
    citations: dict[str, dict[str, Any]], food_source_id: str, food_reference_code_field: str,
    nutrient_units: dict[str, str],
    factor_policy: dict[str, Any], allergen_map: dict[str, list[str]],
    default_unresolved_items: list[str],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    if not isinstance(recipe, dict) or not isinstance(recipe.get("payload"), dict):
        raise ManualGraphError("every draft recipe requires an object payload")
    payload = recipe["payload"]
    meal_type = _required_text(payload, "mealType")
    if meal_type not in SUPPORTED_MEAL_TYPES:
        raise ManualGraphError(f"unsupported meal type: {meal_type}")
    ingredients = payload.get("ingredients")
    if not isinstance(ingredients, list) or not ingredients:
        raise ManualGraphError("every recipe requires at least one ingredient")

    ingredient_codes: set[str] = set()
    ingredient_evidence: list[dict[str, Any]] = []
    totals = {key: Decimal("0") for key in nutrient_units}
    calculation_terms = {key: [] for key in nutrient_units}
    calculated_allergens: set[str] = set()

    for ingredient in ingredients:
        code = _required_text(ingredient, "code")
        if code in ingredient_codes:
            raise ManualGraphError(f"recipe {_required_uuid(payload, 'versionId')} repeats ingredient {code}")
        ingredient_codes.add(code)
        if code not in foods:
            raise ManualGraphError(f"ingredient code {code} is missing from the food snapshot")
        if code not in concepts or concepts[code].get("kind") != "ingredient":
            raise ManualGraphError(f"ingredient code {code} is not an ingredient concept")
        food = foods[code]
        basis = _required_text(ingredient, "basis")
        if basis != food.get("basis"):
            raise ManualGraphError(f"ingredient {code} basis {basis} does not match snapshot basis {food.get('basis')}")
        if ingredient.get("unit") != "g":
            raise ManualGraphError(f"ingredient {code} must use grams")
        amount = _positive_decimal(ingredient.get("amount"), f"ingredient {code} amount")
        edible = factor_policy["edible_portion_factor"]
        yield_factor = factor_policy["yield_factor"]
        per_100: dict[str, float | int] = {}
        for nutrient in nutrient_units:
            entry = food["nutrients"][nutrient]
            value = _nonnegative_decimal(entry.get("value"), f"food {code} nutrient {nutrient}")
            per_100[nutrient] = _json_number(value)
            contribution = amount * value / Decimal("100") * edible * yield_factor
            totals[nutrient] += contribution
            calculation_terms[nutrient].append(
                f"{code}: {_decimal_text(amount)} g × {_decimal_text(value)}/100"
                f" × {_decimal_text(edible)} × {_decimal_text(yield_factor)}"
            )
        ingredient_evidence.append({
            "ingredientCode": code,
            "sourceId": food_source_id,
            "sourceReferenceCode": _required_text(food, food_reference_code_field),
            "sourceLocator": _required_text(food, "sourceLocator"),
            "amountBasis": basis,
            "nutrientsPer100G": per_100,
            "ediblePortionFactor": _json_number(edible),
            "yieldFactor": _json_number(yield_factor),
        })
        if code not in allergen_map:
            raise ManualGraphError(f"ingredient {code} has no explicit allergen mapping")
        calculated_allergens.update(allergen_map[code])

    for allergen in calculated_allergens:
        if allergen not in concepts or concepts[allergen].get("kind") != "food_allergy":
            raise ManualGraphError(f"allergen {allergen} is not a food_allergy concept")
    supplied_allergens = set(payload.get("allergens") or [])
    if supplied_allergens != calculated_allergens:
        raise ManualGraphError(
            f"recipe {_required_uuid(payload, 'versionId')} allergens do not match the closed allergen mapping"
        )

    sources = payload.get("sources")
    if not isinstance(sources, list) or not sources:
        raise ManualGraphError("every recipe requires at least one source")
    if food_source_id not in sources:
        sources = [*sources, food_source_id]
    for source in sources:
        if source not in citations:
            raise ManualGraphError(f"recipe source {source} does not exist in citations")

    dietary_patterns = _nonempty_text_array(payload.get("dietaryPatterns"), "dietaryPatterns")
    if len(set(dietary_patterns)) != len(dietary_patterns):
        raise ManualGraphError("dietaryPatterns cannot contain duplicates")
    unsupported_patterns = sorted(set(dietary_patterns) - SUPPORTED_DIETARY_PATTERNS)
    if unsupported_patterns:
        raise ManualGraphError(f"unsupported dietary patterns: {', '.join(unsupported_patterns)}")
    image_url, image_alt = _optional_recipe_image(payload)

    # Match System.Decimal Math.Round(value, 2), which uses midpoint-to-even.
    rounded = {key: _json_number(value.quantize(DECIMAL_PLACES, rounding=ROUND_HALF_EVEN)) for key, value in totals.items()}
    candidate_payload = {
        "versionId": _required_uuid(payload, "versionId"),
        "name": _required_text(payload, "name"),
        "mealType": meal_type,
        "servings": _json_number(_positive_decimal(payload.get("servings"), "recipe servings")),
        "ingredients": deepcopy(ingredients),
        "allergens": sorted(calculated_allergens),
        "nutrients": rounded,
        "preparationSteps": _nonempty_text_array(payload.get("preparationSteps"), "preparationSteps"),
        "sources": sorted(set(sources)),
        "allergenDataComplete": True,
        "dietaryPatterns": sorted(dietary_patterns),
    }
    if image_url is not None:
        candidate_payload["imageUrl"] = image_url
        candidate_payload["imageAlt"] = image_alt
    candidate = {
        "recipeId": _required_uuid(recipe, "recipeId"),
        "version": recipe.get("version"),
        "payload": candidate_payload,
    }
    if not isinstance(candidate["version"], int) or candidate["version"] <= 0:
        raise ManualGraphError("recipe version must be a positive integer")

    unresolved = [*default_unresolved_items, *((recipe.get("authoring") or {}).get("unresolvedItems") or [])]
    if factor_policy["status"] != "approved":
        unresolved.append(factor_policy["rationale"])
    if any(not isinstance(item, str) or not item.strip() for item in unresolved):
        raise ManualGraphError("unresolved items must be non-empty strings")
    evidence = {
        "recipeVersionId": candidate_payload["versionId"],
        "ingredients": ingredient_evidence,
        "nutrients": [
            {
                "key": key,
                "value": rounded[key],
                "unit": nutrient_units[key],
                "method": "ingredient_sum_per_100g",
                "sourceIds": [food_source_id],
                "calculation": " + ".join(calculation_terms[key]),
            }
            for key in nutrient_units
        ],
        "unresolvedItems": sorted(set(unresolved)),
    }
    card = {
        "recipe_id": candidate["recipeId"],
        "recipe_version_id": candidate_payload["versionId"],
        "name": candidate_payload["name"],
        "meal_type": meal_type,
        "ingredients": deepcopy(candidate_payload["ingredients"]),
        "allergens": deepcopy(candidate_payload["allergens"]),
        "nutrients": deepcopy(candidate_payload["nutrients"]),
        "nutrient_calculations": deepcopy(evidence["nutrients"]),
        "preparation_steps": deepcopy(candidate_payload["preparationSteps"]),
        "sources": deepcopy(candidate_payload["sources"]),
        "unresolved_items": deepcopy(evidence["unresolvedItems"]),
    }
    return candidate, evidence, card


def _optional_recipe_image(payload: dict[str, Any]) -> tuple[str | None, str | None]:
    image_url = payload.get("imageUrl")
    image_alt = payload.get("imageAlt")
    if image_url is None and image_alt is None:
        return None, None
    if not isinstance(image_url, str) or not image_url.strip():
        raise ManualGraphError("recipe imageUrl is required when imageAlt is provided")
    if len(image_url) > 2048:
        raise ManualGraphError("recipe imageUrl cannot exceed 2048 characters")
    parsed = urlsplit(image_url)
    if parsed.scheme.lower() != "https" or not parsed.netloc:
        raise ManualGraphError("recipe imageUrl must be an absolute HTTPS URL")
    if not isinstance(image_alt, str) or not image_alt.strip():
        raise ManualGraphError("recipe imageAlt is required when imageUrl is provided")
    if len(image_alt) > 200:
        raise ManualGraphError("recipe imageAlt cannot exceed 200 characters")
    return image_url.strip(), image_alt.strip()


def _combination_coverage(
    recipes: list[dict[str, Any]], nutrient_units: dict[str, str], targets: dict[str, Any]
) -> dict[str, Any]:
    by_meal = {
        meal: [item for item in recipes if item["payload"]["mealType"] == meal]
        for meal in SUPPORTED_MEAL_TYPES
    }
    combinations: list[dict[str, Any]] = []
    for selected in product(*(by_meal[meal] for meal in SUPPORTED_MEAL_TYPES)):
        totals = {
            nutrient: sum(Decimal(str(item["payload"]["nutrients"][nutrient])) for item in selected)
            for nutrient in nutrient_units
        }
        flags: list[str] = []
        for nutrient, limits in targets.items():
            if nutrient not in totals or not isinstance(limits, dict):
                raise ManualGraphError(f"daily target references invalid nutrient {nutrient}")
            minimum = limits.get("minimum")
            maximum = limits.get("maximum")
            if minimum is not None and totals[nutrient] < _nonnegative_decimal(minimum, f"target {nutrient} minimum"):
                flags.append(f"{nutrient}:below_minimum")
            if maximum is not None and totals[nutrient] > _nonnegative_decimal(maximum, f"target {nutrient} maximum"):
                flags.append(f"{nutrient}:above_maximum")
        combinations.append({
            "recipe_version_ids": [item["payload"]["versionId"] for item in selected],
            "nutrients": {
                key: _json_number(value.quantize(DECIMAL_PLACES, rounding=ROUND_HALF_EVEN))
                for key, value in totals.items()
            },
            "flags": flags,
        })
    return {
        "meal_option_counts": {meal: len(by_meal[meal]) for meal in SUPPORTED_MEAL_TYPES},
        "combination_count": len(combinations),
        "flagged_combination_count": sum(1 for item in combinations if item["flags"]),
        "daily_targets": deepcopy(targets),
        "combinations": combinations,
    }


def _validate_profile(profile: dict[str, Any], *, require_authoring: bool) -> None:
    if profile.get("schema_version") != 1:
        raise ManualGraphError("catalog profile schema_version must be 1")
    if profile.get("release_profile") != SUPPORTED_RELEASE_PROFILE:
        raise ManualGraphError("only adult_baseline_v1 authoring is supported")
    for field in ("profile_id", "package_key", "product_semantics", "food_source_id", "food_reference_code_field"):
        _required_text(profile, field)
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", profile["package_key"]):
        raise ManualGraphError("package_key must use lower-case kebab-case")
    if require_authoring and not profile.get("authoring_enabled"):
        raise ManualGraphError("catalog authoring is disabled for this profile")
    if profile.get("product_semantics") not in {"meal_suggestions", "full_day_menu", "deferred"}:
        raise ManualGraphError("unsupported product semantics")
    if require_authoring and profile.get("product_semantics") == "deferred":
        raise ManualGraphError("product semantics must be decided before catalog authoring")
    if profile.get("product_semantics") == "full_day_menu" and not profile.get("daily_targets"):
        raise ManualGraphError("full_day_menu requires explicit daily targets")


def _validate_input_bindings(profile: dict[str, Any], actual: dict[str, str]) -> None:
    expected = profile.get("input_file_sha256") or {}
    if not isinstance(expected, dict):
        raise ManualGraphError("profile input_file_sha256 must be an object")
    for key, digest in expected.items():
        if digest and actual.get(key, "").lower() != str(digest).lower():
            raise ManualGraphError(f"input file hash mismatch: {key}")


def _validate_manifest(
    manifest: dict[str, Any], bundle: dict[str, Any], evidence: dict[str, Any], profile: dict[str, Any]
) -> None:
    supplied_hash = manifest.get("content_sha256")
    unsigned = {key: value for key, value in manifest.items() if key != "content_sha256"}
    if supplied_hash != content_sha256(unsigned):
        raise ManualGraphError("candidate manifest content hash is invalid")
    if manifest.get("profile_id") != profile.get("profile_id") or manifest.get("package_key") != profile.get("package_key"):
        raise ManualGraphError("candidate manifest does not match the selected profile")
    if manifest.get("profile_content_sha256") != content_sha256(profile):
        raise ManualGraphError("candidate manifest is not bound to the exact catalog profile")
    artifacts = manifest.get("artifacts") or {}
    for key, value in (("candidate_bundle", bundle), ("candidate_evidence", evidence)):
        expected = artifacts.get(key) or {}
        actual = _artifact_digest(value)
        if expected != actual:
            raise ManualGraphError(f"candidate {key} hash is invalid")
    if evidence.get("bundleFileSha256") != serialized_json_sha256(bundle):
        raise ManualGraphError("candidate evidence is not bound to the exact bundle file")


def _validate_approval(value: Any, roles: set[str], label: str, version_id: str) -> dict[str, Any]:
    if not isinstance(value, dict) or value.get("decision") != "approved":
        raise ManualGraphError(f"recipe {version_id} requires an approved {label} review")
    if value.get("reviewer_role") not in roles:
        raise ManualGraphError(f"recipe {version_id} has an invalid {label} reviewer role")
    _required_text(value, "reviewer_id")
    _required_text(value, "comment")
    return value


def _validate_resolutions(
    unresolved: list[str], resolutions: list[Any], decision: dict[str, Any], version_id: str
) -> None:
    if not isinstance(resolutions, list):
        raise ManualGraphError(f"recipe {version_id} resolutions must be an array")
    resolved_items: set[str] = set()
    approved_reviewers = {
        (review["reviewer_id"], review["reviewer_role"])
        for review in (decision.get("data_review"), decision.get("clinical_review"))
        if isinstance(review, dict) and review.get("decision") == "approved"
    }
    for resolution in resolutions:
        if not isinstance(resolution, dict):
            raise ManualGraphError(f"recipe {version_id} has an invalid resolution")
        item = _required_text(resolution, "item")
        _required_text(resolution, "resolution")
        resolver = (_required_text(resolution, "reviewer_id"), _required_text(resolution, "reviewer_role"))
        if resolver not in approved_reviewers:
            raise ManualGraphError(f"recipe {version_id} resolution is not bound to an approved reviewer")
        if item in resolved_items:
            raise ManualGraphError(f"recipe {version_id} repeats an unresolved-item resolution")
        resolved_items.add(item)
    if resolved_items != set(unresolved):
        raise ManualGraphError(f"recipe {version_id} must resolve every unresolved item exactly once")


def _required_nutrient_units(profile: dict[str, Any]) -> dict[str, str]:
    value = profile.get("required_nutrients")
    if not isinstance(value, dict) or not value:
        raise ManualGraphError("required_nutrients must be a non-empty object")
    result: dict[str, str] = {}
    for key, unit in value.items():
        if not isinstance(key, str) or not key or not isinstance(unit, str) or not unit:
            raise ManualGraphError("required nutrient names and units must be non-empty strings")
        result[key] = unit
    return result


def _expected_recipe_counts(profile: dict[str, Any]) -> dict[str, int]:
    value = profile.get("expected_recipe_counts")
    if not isinstance(value, dict) or set(value) != set(SUPPORTED_MEAL_TYPES):
        raise ManualGraphError("expected_recipe_counts must define breakfast, lunch and dinner")
    if any(not isinstance(value[key], int) or value[key] <= 0 for key in SUPPORTED_MEAL_TYPES):
        raise ManualGraphError("expected recipe counts must be positive integers")
    return value


def _validate_meal_counts(recipes: list[Any], expected: dict[str, int]) -> None:
    counts = {meal: 0 for meal in SUPPORTED_MEAL_TYPES}
    for recipe in recipes:
        payload = recipe.get("payload") if isinstance(recipe, dict) else None
        meal = payload.get("mealType") if isinstance(payload, dict) else None
        if meal not in counts:
            raise ManualGraphError(f"unsupported meal type: {meal}")
        counts[meal] += 1
    if counts != expected:
        raise ManualGraphError(f"recipe meal counts {counts} do not match profile {expected}")


def _baseline_scope(profile: dict[str, Any]) -> dict[str, Any]:
    value = profile.get("scope")
    if not isinstance(value, dict):
        raise ManualGraphError("catalog profile scope is required")
    if value.get("population") != "adult" or value.get("conditionCodes") != []:
        raise ManualGraphError("adult baseline scope must be adult with no condition codes")
    if value.get("medicationPolicy") != "reported_none_only":
        raise ManualGraphError("adult baseline requires reported_none_only medication policy")
    blocked = value.get("blockedSpecialNeeds")
    required_blocks = {
        "KIDNEY_DISEASE", "DYSPHAGIA", "TUBE_FEEDING", "FLUID_RESTRICTION", "ELECTROLYTE_RESTRICTION"
    }
    if not isinstance(blocked, list) or not required_blocks.issubset(set(blocked)):
        raise ManualGraphError("adult baseline is missing required blocked special needs")
    _required_text(value, "code")
    return deepcopy(value)


def _factor_policy(profile: dict[str, Any]) -> dict[str, Any]:
    value = profile.get("factor_policy")
    if not isinstance(value, dict):
        raise ManualGraphError("factor_policy is required")
    status = value.get("status")
    if status not in {"approved", "unresolved"}:
        raise ManualGraphError("factor policy status must be approved or unresolved")
    return {
        "status": status,
        "edible_portion_factor": _positive_decimal(value.get("edible_portion_factor"), "edible portion factor"),
        "yield_factor": _positive_decimal(value.get("yield_factor"), "yield factor"),
        "rationale": _required_text(value, "rationale"),
    }


def _allergen_map(profile: dict[str, Any]) -> dict[str, list[str]]:
    value = profile.get("ingredient_allergens")
    if not isinstance(value, dict):
        raise ManualGraphError("ingredient_allergens must be an object")
    result: dict[str, list[str]] = {}
    for code, allergens in value.items():
        if not isinstance(code, str) or not code or not isinstance(allergens, list):
            raise ManualGraphError("invalid ingredient allergen mapping")
        if len(allergens) != len(set(allergens)) or any(not isinstance(item, str) or not item for item in allergens):
            raise ManualGraphError(f"invalid allergen list for ingredient {code}")
        result[code] = sorted(allergens)
    return result


def _default_unresolved_items(profile: dict[str, Any]) -> list[str]:
    value = profile.get("default_recipe_unresolved_items") or []
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        raise ManualGraphError("default_recipe_unresolved_items must contain non-empty strings")
    if len(value) != len(set(value)):
        raise ManualGraphError("default_recipe_unresolved_items cannot contain duplicates")
    return [item.strip() for item in value]


def _food_index(
    snapshot: dict[str, Any], nutrient_units: dict[str, str], reference_code_field: str
) -> dict[str, dict[str, Any]]:
    foods = _unique_by(snapshot.get("foods"), "conceptCode", "food snapshot")
    for code, food in foods.items():
        if food.get("perAmount") != 100 or food.get("perUnit") != "g":
            raise ManualGraphError(f"food {code} must provide values per 100 g")
        _required_text(food, "basis")
        _required_text(food, reference_code_field)
        _required_text(food, "sourceLocator")
        nutrients = food.get("nutrients")
        if not isinstance(nutrients, dict):
            raise ManualGraphError(f"food {code} has no nutrient object")
        for nutrient, expected_unit in nutrient_units.items():
            item = nutrients.get(nutrient)
            if not isinstance(item, dict) or item.get("unit") != expected_unit:
                raise ManualGraphError(f"food {code} has missing or wrong unit for {nutrient}")
            _nonnegative_decimal(item.get("value"), f"food {code} nutrient {nutrient}")
    return foods


def _unique_by(value: Any, key: str, label: str) -> dict[str, dict[str, Any]]:
    if not isinstance(value, list):
        raise ManualGraphError(f"{label} must be an array")
    result: dict[str, dict[str, Any]] = {}
    for item in value:
        if not isinstance(item, dict):
            raise ManualGraphError(f"{label} entries must be objects")
        identity = _required_text(item, key)
        if identity in result:
            raise ManualGraphError(f"{label} repeats {key} {identity}")
        result[identity] = item
    return result


def _artifact_digest(value: dict[str, Any]) -> dict[str, str]:
    return {
        "content_sha256": content_sha256(value),
        "file_sha256": serialized_json_sha256(value),
    }


def _calculation_basis(policy: dict[str, Any]) -> str:
    return (
        "Sum each ingredient amount in grams against per-100-g nutrient values; "
        f"edible portion factor={_decimal_text(policy['edible_portion_factor'])}; "
        f"yield factor={_decimal_text(policy['yield_factor'])}; round half up to 2 decimals. "
        f"Factor decision: {policy['status']} ({policy['rationale']})."
    )


def _required_text(value: dict[str, Any], key: str) -> str:
    result = value.get(key) if isinstance(value, dict) else None
    if not isinstance(result, str) or not result.strip():
        raise ManualGraphError(f"{key} is required")
    return result.strip()


def _required_uuid(value: dict[str, Any], key: str) -> str:
    result = _required_text(value, key)
    try:
        parsed = UUID(result)
    except ValueError:
        raise ManualGraphError(f"{key} must be a UUID") from None
    if parsed.int == 0:
        raise ManualGraphError(f"{key} cannot be an empty UUID")
    return result


def _nonempty_text_array(value: Any, label: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item.strip() for item in value):
        raise ManualGraphError(f"{label} must contain non-empty strings")
    return [item.strip() for item in value]


def _positive_decimal(value: Any, label: str) -> Decimal:
    result = _decimal(value, label)
    if result <= 0:
        raise ManualGraphError(f"{label} must be positive")
    return result


def _nonnegative_decimal(value: Any, label: str) -> Decimal:
    result = _decimal(value, label)
    if result < 0:
        raise ManualGraphError(f"{label} cannot be negative")
    return result


def _decimal(value: Any, label: str) -> Decimal:
    if isinstance(value, bool) or value is None:
        raise ManualGraphError(f"{label} must be numeric")
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise ManualGraphError(f"{label} must be numeric") from None
    if not result.is_finite():
        raise ManualGraphError(f"{label} must be finite")
    return result


def _json_number(value: Decimal) -> int | float:
    if value == value.to_integral_value():
        return int(value)
    return float(value)


def _decimal_text(value: Decimal) -> str:
    return format(value.normalize(), "f")
