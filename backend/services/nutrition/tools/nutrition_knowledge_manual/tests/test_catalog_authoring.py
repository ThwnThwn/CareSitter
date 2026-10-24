from __future__ import annotations

from copy import deepcopy
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
import unittest
from uuid import NAMESPACE_URL, uuid5

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[4]
sys.path.insert(0, str(ROOT / "src"))

from nutrition_knowledge_manual.catalog_authoring import (
    finalize_catalog_candidate,
    prepare_catalog_candidate,
)
from nutrition_knowledge_manual.catalog_review import (
    catalog_review_status,
    empty_catalog_review,
    record_catalog_clinical_review,
    record_recipe_review,
    validate_catalog_review_ledger,
)
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.cli import main as cli_main
from nutrition_knowledge_manual.jsonio import file_sha256, load_json, write_json


NUTRIENTS = {
    "energy_kcal": "kcal",
    "protein_g": "g",
    "carbohydrate_g": "g",
    "fat_g": "g",
    "fiber_g": "g",
    "sodium_mg": "mg",
}


def _profile() -> dict:
    return {
        "schema_version": 1,
        "profile_id": "synthetic-baseline-v1",
        "package_key": "synthetic-baseline-v1",
        "release_profile": "adult_baseline_v1",
        "authoring_enabled": True,
        "release_enabled": True,
        "product_semantics": "meal_suggestions",
        "scope": {
            "code": "synthetic-adult-baseline",
            "population": "adult",
            "conditionCodes": [],
            "medicationPolicy": "reported_none_only",
            "blockedSpecialNeeds": [
                "KIDNEY_DISEASE", "DYSPHAGIA", "TUBE_FEEDING",
                "FLUID_RESTRICTION", "ELECTROLYTE_RESTRICTION",
            ],
        },
        "food_source_id": "SYNTHETIC_FOOD_TABLE",
        "food_reference_code_field": "ninCode",
        "required_nutrients": NUTRIENTS,
        "expected_recipe_counts": {"breakfast": 4, "lunch": 4, "dinner": 4},
        "factor_policy": {
            "status": "approved",
            "edible_portion_factor": 1,
            "yield_factor": 1,
            "rationale": "Synthetic identity factors for automated tests only.",
        },
        "ingredient_allergens": {"SYNTHETIC_RICE": []},
        "daily_targets": {"energy_kcal": {"minimum": 300, "maximum": 400}},
        "input_file_sha256": {"draft": "a" * 64, "food_snapshot": "b" * 64},
    }


def _snapshot() -> dict:
    values = {
        "energy_kcal": 100,
        "protein_g": 10,
        "carbohydrate_g": 20,
        "fat_g": 2,
        "fiber_g": 3,
        "sodium_mg": 4,
    }
    return {
        "schemaVersion": 1,
        "foods": [{
            "conceptCode": "SYNTHETIC_RICE",
            "ninCode": "SYNTHETIC-1001",
            "nameVi": "Gạo giả lập",
            "basis": "raw",
            "perAmount": 100,
            "perUnit": "g",
            "nutrients": {
                key: {"value": value, "unit": NUTRIENTS[key], "sourceKey": key}
                for key, value in values.items()
            },
            "sourceLocator": "synthetic://food-table/rice",
        }],
    }


def _draft() -> dict:
    recipes = []
    for meal in ("breakfast", "lunch", "dinner"):
        for index in range(4):
            recipe_id = str(uuid5(NAMESPACE_URL, f"recipe:{meal}:{index}"))
            version_id = str(uuid5(NAMESPACE_URL, f"recipe-version:{meal}:{index}"))
            recipes.append({
                "recipeId": recipe_id,
                "version": 1,
                "payload": {
                    "versionId": version_id,
                    "name": f"Synthetic {meal} {index + 1}",
                    "mealType": meal,
                    "imageUrl": f"https://images.example.test/{meal}.jpg",
                    "imageAlt": f"Synthetic {meal} illustration",
                    "servings": 1,
                    "ingredients": [{
                        "code": "SYNTHETIC_RICE",
                        "name": "Gạo giả lập",
                        "amount": 100 + index,
                        "unit": "g",
                        "basis": "raw",
                    }],
                    "allergens": [],
                    "nutrients": {key: 999 for key in NUTRIENTS},
                    "preparationSteps": ["Synthetic fixture only."],
                    "sources": ["SYNTHETIC_FOOD_TABLE"],
                    "allergenDataComplete": True,
                    "dietaryPatterns": ["vegetarian"],
                },
            })
    return {
        "schemaVersion": 2,
        "packageKey": "ignored-draft-key",
        "supportedScopes": [],
        "citations": [{
            "id": "SYNTHETIC_FOOD_TABLE",
            "title": "Synthetic food table",
            "organization": "CareSitter engineering",
            "year": 2026,
            "edition": "fixture",
            "chapter": "fixture",
            "printedPages": None,
            "pdfPages": None,
            "locator": "synthetic fixture",
            "reference": "synthetic://food-table",
            "verifiedOn": "2026-10-20",
            "fileSha256": None,
        }],
        "concepts": [{
            "code": "SYNTHETIC_RICE",
            "kind": "ingredient",
            "aliases": ["Gạo giả lập"],
            "version": 1,
        }],
        "recipes": recipes,
        "rules": [],
    }


def _prepare(profile: dict | None = None, draft: dict | None = None, snapshot: dict | None = None):
    return prepare_catalog_candidate(
        profile=profile or _profile(),
        draft=draft or _draft(),
        food_snapshot=snapshot or _snapshot(),
        input_file_sha256={"draft": "a" * 64, "food_snapshot": "b" * 64},
    )


def _decisions(prepared: dict) -> dict:
    manifest = prepared["manifest"]
    ledger = empty_catalog_review(manifest)
    for candidate in manifest["recipe_candidates"]:
        for reviewer_id, reviewer_role, comment in (
            ("synthetic-steward", "data_steward", "Synthetic calculation review only."),
            ("synthetic-dietitian", "dietitian", "Synthetic clinical gate test only."),
        ):
            ledger = record_recipe_review(
                candidate_manifest=manifest,
                ledger=ledger,
                recipe_version_id=candidate["recipe_version_id"],
                decision="approved",
                reviewer_id=reviewer_id,
                reviewer_role=reviewer_role,
                comment=comment,
                reviewed_at_utc="2026-10-20T00:00:00+00:00",
            )
    return record_catalog_clinical_review(
        candidate_manifest=manifest,
        ledger=ledger,
        reviewer_name="Synthetic reviewer",
        reviewer_id="synthetic-dietitian",
        credentials="Automated fixture; not a real clinical approval",
        decision="approved",
        notes="Synthetic fixture only.",
        reviewed_at="2026-10-20T00:00:00+07:00",
    )


class CatalogAuthoringTests(unittest.TestCase):
    def test_cli_prepares_candidate_initializes_ledger_and_reports_pending_status(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            profile_path = root / "profile.json"
            draft_path = root / "draft.json"
            snapshot_path = root / "snapshot.json"
            output_dir = root / "output"
            write_json(draft_path, _draft())
            write_json(snapshot_path, _snapshot())
            profile = _profile()
            profile["input_file_sha256"] = {
                "draft": file_sha256(draft_path),
                "food_snapshot": file_sha256(snapshot_path),
            }
            write_json(profile_path, profile)
            with redirect_stdout(StringIO()):
                prepare_exit = cli_main([
                    "--workspace", str(root),
                    "prepare-catalog-candidate",
                    "--profile", str(profile_path),
                    "--draft", str(draft_path),
                    "--food-snapshot", str(snapshot_path),
                    "--output-dir", str(output_dir),
                ])
            manifest_path = output_dir / "synthetic-baseline-v1.candidate-manifest.json"
            evidence_path = output_dir / "synthetic-baseline-v1.candidate.evidence.json"
            ledger_path = output_dir / "synthetic-baseline-v1.review-ledger.json"
            with redirect_stdout(StringIO()):
                init_exit = cli_main([
                    "--workspace", str(root),
                    "init-catalog-review",
                    "--candidate-manifest", str(manifest_path),
                    "--output", str(ledger_path),
                ])
                status_exit = cli_main([
                    "--workspace", str(root),
                    "catalog-review-status",
                    "--candidate-manifest", str(manifest_path),
                    "--candidate-evidence", str(evidence_path),
                    "--ledger", str(ledger_path),
                ])
            self.assertEqual(0, prepare_exit)
            self.assertEqual(0, init_exit)
            self.assertEqual(0, status_exit)
            self.assertTrue(manifest_path.exists())
            self.assertEqual(12, len(load_json(ledger_path)["decisions"]))

    def test_candidate_preserves_only_supported_dietary_patterns(self):
        prepared = _prepare()
        self.assertTrue(all(
            recipe["payload"]["dietaryPatterns"] == ["vegetarian"]
            for recipe in prepared["bundle"]["recipes"]
        ))

        draft = _draft()
        draft["recipes"][0]["payload"]["dietaryPatterns"] = ["pescatarian"]
        with self.assertRaisesRegex(ManualGraphError, "unsupported dietary patterns"):
            _prepare(draft=draft)

    def test_candidate_allows_empty_patterns_for_regular_diet_recipes(self):
        draft = _draft()
        draft["recipes"][0]["payload"]["dietaryPatterns"] = []

        prepared = _prepare(draft=draft)

        self.assertEqual([], prepared["bundle"]["recipes"][0]["payload"]["dietaryPatterns"])

    def test_candidate_preserves_only_accessible_https_recipe_images(self):
        prepared = _prepare()
        payload = prepared["bundle"]["recipes"][0]["payload"]
        self.assertEqual("https://images.example.test/breakfast.jpg", payload["imageUrl"])
        self.assertEqual("Synthetic breakfast illustration", payload["imageAlt"])

        draft = _draft()
        draft["recipes"][0]["payload"]["imageUrl"] = "http://images.example.test/breakfast.jpg"
        with self.assertRaisesRegex(ManualGraphError, "absolute HTTPS URL"):
            _prepare(draft=draft)

    def test_review_ledger_is_initialized_for_every_recipe_and_hash_bound(self):
        prepared = _prepare()
        ledger = empty_catalog_review(prepared["manifest"])
        candidates = validate_catalog_review_ledger(prepared["manifest"], ledger)
        status = catalog_review_status(
            candidate_manifest=prepared["manifest"],
            candidate_evidence=prepared["evidence"],
            ledger=ledger,
        )
        self.assertEqual(12, len(ledger["decisions"]))
        self.assertEqual(12, len(candidates))
        self.assertTrue(all(item["data_review"] is None for item in ledger["decisions"]))
        self.assertEqual(12, status["data_pending"])
        self.assertEqual(12, status["clinical_pending"])
        self.assertFalse(status["ready_for_finalize"])

    def test_review_ledger_rejects_tampering_before_recording_next_review(self):
        prepared = _prepare()
        ledger = empty_catalog_review(prepared["manifest"])
        ledger["decisions"][0]["candidate_sha256"] = "0" * 64
        with self.assertRaisesRegex(ManualGraphError, "content hash is invalid"):
            record_recipe_review(
                candidate_manifest=prepared["manifest"],
                ledger=ledger,
                recipe_version_id=ledger["decisions"][0]["recipe_version_id"],
                decision="approved",
                reviewer_id="steward",
                reviewer_role="data_steward",
                comment="Synthetic review.",
            )

    def test_review_ledger_keeps_data_and_clinical_reviews_separate(self):
        prepared = _prepare()
        manifest = prepared["manifest"]
        ledger = empty_catalog_review(manifest)
        recipe_id = ledger["decisions"][0]["recipe_version_id"]
        ledger = record_recipe_review(
            candidate_manifest=manifest,
            ledger=ledger,
            recipe_version_id=recipe_id,
            decision="approved",
            reviewer_id="steward",
            reviewer_role="data_steward",
            comment="Synthetic data review.",
            reviewed_at_utc="2026-10-20T00:00:00+00:00",
        )
        ledger = record_recipe_review(
            candidate_manifest=manifest,
            ledger=ledger,
            recipe_version_id=recipe_id,
            decision="approved",
            reviewer_id="dietitian",
            reviewer_role="dietitian",
            comment="Synthetic clinical review.",
            reviewed_at_utc="2026-10-20T00:00:00+00:00",
        )
        entry = ledger["decisions"][0]
        self.assertEqual("steward", entry["data_review"]["reviewer_id"])
        self.assertEqual("dietitian", entry["clinical_review"]["reviewer_id"])

    def test_prepare_is_deterministic_and_builds_all_combinations(self):
        first = _prepare()
        second = _prepare()
        self.assertEqual(first, second)
        self.assertEqual(12, len(first["bundle"]["recipes"]))
        self.assertEqual(64, first["review_packet"]["combination_coverage"]["combination_count"])
        self.assertEqual(first["manifest"]["content_sha256"], second["manifest"]["content_sha256"])

    def test_prepare_recomputes_nutrients_instead_of_trusting_draft(self):
        result = _prepare()
        recipe = result["bundle"]["recipes"][0]["payload"]
        ingredient_evidence = result["evidence"]["recipes"][0]["ingredients"][0]
        self.assertEqual(100, recipe["nutrients"]["energy_kcal"])
        self.assertEqual(10, recipe["nutrients"]["protein_g"])
        self.assertNotEqual(999, recipe["nutrients"]["energy_kcal"])
        self.assertEqual("SYNTHETIC-1001", ingredient_evidence["sourceReferenceCode"])

    def test_prepare_uses_dotnet_midpoint_to_even_rounding(self):
        snapshot = _snapshot()
        snapshot["foods"][0]["nutrients"]["energy_kcal"]["value"] = 1.005

        result = _prepare(snapshot=snapshot)

        self.assertEqual(1, result["bundle"]["recipes"][0]["payload"]["nutrients"]["energy_kcal"])

    def test_prepare_rejects_unknown_ingredient_code(self):
        draft = _draft()
        draft["recipes"][0]["payload"]["ingredients"][0]["code"] = "UNKNOWN"
        with self.assertRaisesRegex(ManualGraphError, "missing from the food snapshot"):
            _prepare(draft=draft)

    def test_prepare_rejects_duplicate_food_code(self):
        snapshot = _snapshot()
        snapshot["foods"].append(deepcopy(snapshot["foods"][0]))
        with self.assertRaisesRegex(ManualGraphError, "repeats conceptCode"):
            _prepare(snapshot=snapshot)

    def test_prepare_rejects_wrong_amount_basis(self):
        draft = _draft()
        draft["recipes"][0]["payload"]["ingredients"][0]["basis"] = "cooked"
        with self.assertRaisesRegex(ManualGraphError, "does not match snapshot basis"):
            _prepare(draft=draft)

    def test_prepare_rejects_changed_input_hash(self):
        profile = _profile()
        profile["input_file_sha256"]["draft"] = "c" * 64
        with self.assertRaisesRegex(ManualGraphError, "input file hash mismatch: draft"):
            _prepare(profile=profile)

    def test_prepare_has_no_filesystem_side_effect(self):
        with tempfile.TemporaryDirectory() as folder:
            before = list(Path(folder).iterdir())
            _prepare()
            after = list(Path(folder).iterdir())
        self.assertEqual(before, after)

    def test_finalize_requires_profile_release_switch(self):
        prepared = _prepare()
        disabled = _profile()
        disabled["release_enabled"] = False
        with self.assertRaisesRegex(ManualGraphError, "finalization is disabled"):
            finalize_catalog_candidate(
                profile=disabled,
                candidate_manifest=prepared["manifest"],
                candidate_bundle=prepared["bundle"],
                candidate_evidence=prepared["evidence"],
                decisions=_decisions(prepared),
            )

    def test_finalize_rejects_stale_recipe_decision(self):
        prepared = _prepare()
        decisions = _decisions(prepared)
        decisions["decisions"][0]["candidate_sha256"] = "0" * 64
        with self.assertRaisesRegex(ManualGraphError, "content hash is invalid"):
            finalize_catalog_candidate(
                profile=_profile(),
                candidate_manifest=prepared["manifest"],
                candidate_bundle=prepared["bundle"],
                candidate_evidence=prepared["evidence"],
                decisions=decisions,
            )

    def test_finalize_rejects_profile_changed_after_candidate_creation(self):
        profile = _profile()
        prepared = _prepare(profile=profile)
        changed = deepcopy(profile)
        changed["factor_policy"]["rationale"] = "Changed after review."
        with self.assertRaisesRegex(ManualGraphError, "exact catalog profile"):
            finalize_catalog_candidate(
                profile=changed,
                candidate_manifest=prepared["manifest"],
                candidate_bundle=prepared["bundle"],
                candidate_evidence=prepared["evidence"],
                decisions=_decisions(prepared),
            )

    def test_finalize_requires_resolution_for_every_unresolved_item(self):
        profile = _profile()
        profile["factor_policy"]["status"] = "unresolved"
        prepared = _prepare(profile=profile)
        with self.assertRaisesRegex(ManualGraphError, "resolve every unresolved item"):
            finalize_catalog_candidate(
                profile=profile,
                candidate_manifest=prepared["manifest"],
                candidate_bundle=prepared["bundle"],
                candidate_evidence=prepared["evidence"],
                decisions=_decisions(prepared),
            )

    def test_finalize_accepts_explicit_resolution_for_every_unresolved_item(self):
        profile = _profile()
        profile["factor_policy"]["status"] = "unresolved"
        prepared = _prepare(profile=profile)
        manifest = prepared["manifest"]
        unresolved_by_recipe = {
            item["recipeVersionId"]: item["unresolvedItems"]
            for item in prepared["evidence"]["recipes"]
        }
        ledger = empty_catalog_review(manifest)
        for candidate in manifest["recipe_candidates"]:
            recipe_id = candidate["recipe_version_id"]
            ledger = record_recipe_review(
                candidate_manifest=manifest,
                ledger=ledger,
                recipe_version_id=recipe_id,
                decision="approved",
                reviewer_id="synthetic-steward",
                reviewer_role="data_steward",
                comment="Synthetic calculation review only.",
                reviewed_at_utc="2026-10-20T00:00:00+00:00",
            )
            ledger = record_recipe_review(
                candidate_manifest=manifest,
                ledger=ledger,
                recipe_version_id=recipe_id,
                decision="approved",
                reviewer_id="synthetic-dietitian",
                reviewer_role="dietitian",
                comment="Synthetic clinical review only.",
                resolutions=[
                    {"item": item, "resolution": "Approved for this synthetic fixture only."}
                    for item in unresolved_by_recipe[recipe_id]
                ],
                reviewed_at_utc="2026-10-20T00:00:00+00:00",
            )
        ledger = record_catalog_clinical_review(
            candidate_manifest=manifest,
            ledger=ledger,
            reviewer_name="Synthetic reviewer",
            reviewer_id="synthetic-dietitian",
            credentials="Automated fixture; not a real clinical approval",
            decision="approved",
            reviewed_at="2026-10-20T00:00:00+07:00",
        )
        result = finalize_catalog_candidate(
            profile=profile,
            candidate_manifest=manifest,
            candidate_bundle=prepared["bundle"],
            candidate_evidence=prepared["evidence"],
            decisions=ledger,
        )
        self.assertTrue(all(not item["unresolvedItems"] for item in result["evidence"]["recipes"]))

    def test_finalize_rejects_a_rejected_recipe_review(self):
        prepared = _prepare()
        ledger = _decisions(prepared)
        first = ledger["decisions"][0]
        ledger = record_recipe_review(
            candidate_manifest=prepared["manifest"],
            ledger=ledger,
            recipe_version_id=first["recipe_version_id"],
            decision="rejected",
            reviewer_id="synthetic-dietitian",
            reviewer_role="dietitian",
            comment="Rejected in synthetic negative test.",
            reviewed_at_utc="2026-10-20T01:00:00+00:00",
        )
        with self.assertRaisesRegex(ManualGraphError, "approved clinical review"):
            finalize_catalog_candidate(
                profile=_profile(),
                candidate_manifest=prepared["manifest"],
                candidate_bundle=prepared["bundle"],
                candidate_evidence=prepared["evidence"],
                decisions=ledger,
            )

    def test_finalize_produces_review_ready_evidence_but_keeps_knowledge_gate(self):
        prepared = _prepare()
        decisions = _decisions(prepared)
        status = catalog_review_status(
            candidate_manifest=prepared["manifest"],
            candidate_evidence=prepared["evidence"],
            ledger=decisions,
        )
        result = finalize_catalog_candidate(
            profile=_profile(),
            candidate_manifest=prepared["manifest"],
            candidate_bundle=prepared["bundle"],
            candidate_evidence=prepared["evidence"],
            decisions=decisions,
        )
        self.assertTrue(status["ready_for_finalize"])
        self.assertEqual("review_ready", result["evidence"]["contentStatus"])
        self.assertEqual([], [item for recipe in result["evidence"]["recipes"] for item in recipe["unresolvedItems"]])
        self.assertNotIn("knowledgeReview", result["evidence"])
        self.assertEqual("knowledge_review_required", result["manifest"]["status"])
        self.assertEqual(64, len(result["manifest"]["decision_ledger_sha256"]))

    def test_real_profile_builds_review_only_candidate_and_stays_release_disabled(self):
        profile = load_json(ROOT / "config" / "catalog-profiles" / "adult-baseline-p2a-v1.json")
        draft_path = WORKSPACE / "backend" / "services" / "nutrition" / "catalog" / "drafts" / "adult-hypertension-p2.bundle.json"
        snapshot_path = WORKSPACE / "backend" / "services" / "nutrition" / "catalog" / "sources" / "nin-food-composition-2026-10-23.json"
        result = prepare_catalog_candidate(
            profile=profile,
            draft=load_json(draft_path),
            food_snapshot=load_json(snapshot_path),
            input_file_sha256={
                "draft": file_sha256(draft_path),
                "food_snapshot": file_sha256(snapshot_path),
            },
        )
        self.assertEqual(3, len(result["bundle"]["recipes"]))
        self.assertEqual([], result["bundle"]["rules"])
        self.assertEqual([], result["bundle"]["supportedScopes"][0]["conditionCodes"])
        self.assertEqual(1, result["manifest"]["source_projection"]["omitted_rule_count"])
        self.assertFalse(result["manifest"]["release_enabled"])
        self.assertTrue(all(item["unresolvedItems"] for item in result["evidence"]["recipes"]))

    def test_baseline_rejects_source_rules_without_explicit_projection_policy(self):
        draft = _draft()
        draft["rules"] = [{"ruleId": "not-used"}]
        with self.assertRaisesRegex(ManualGraphError, "forbids disease rules"):
            _prepare(draft=draft)


if __name__ == "__main__":
    unittest.main()
