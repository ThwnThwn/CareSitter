from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[4]
sys.path.insert(0, str(ROOT / "src"))

from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import load_json, write_json
from nutrition_knowledge_manual.source_reference_release import (
    RELEASE_PROFILE,
    build_source_reference_evidence,
    prepare_source_reference_bundle,
)


class SourceReferenceReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.bundle_path = (
            WORKSPACE
            / "backend/services/nutrition/catalog/drafts/adult-baseline-book-demo.bundle.json"
        )
        self.snapshot_path = (
            WORKSPACE
            / "backend/services/nutrition/catalog/sources/nin-food-composition-2026-10-24.json"
        )
        self.index_path = (
            WORKSPACE
            / "backend/services/nutrition/catalog/sources/clinical-nutrition-2019-dish-index.candidate.json"
        )

    def _build(self, bundle: dict | None = None) -> dict:
        source = bundle or load_json(self.bundle_path)
        snapshot = load_json(self.snapshot_path)
        release = prepare_source_reference_bundle(
            source_bundle=source,
            package_key="adult-baseline-book-reference-v1",
            food_snapshot=snapshot,
        )
        with tempfile.TemporaryDirectory() as directory:
            release_path = Path(directory) / "release.bundle.json"
            write_json(release_path, release)
            return build_source_reference_evidence(
                bundle=release,
                bundle_path=release_path,
                food_snapshot=snapshot,
                source_index=load_json(self.index_path),
                authorization_id="product-owner-release-2026-10-24",
                authorized_by="project-owner",
                authorized_at="2026-10-24T07:30:00+07:00",
                notes="User authorized published-source reference release for adult baseline.",
            )

    def test_builds_release_evidence_without_claiming_clinical_review(self) -> None:
        evidence = self._build()

        self.assertEqual(RELEASE_PROFILE, evidence["releaseProfile"])
        self.assertIsNone(evidence["clinicalReview"])
        self.assertEqual("verified", evidence["sourcePublication"]["decision"])
        self.assertEqual("product_owner", evidence["releaseAuthorization"]["authorityType"])
        self.assertEqual(12, len(evidence["recipes"]))
        self.assertTrue(all(not item["unresolvedItems"] for item in evidence["recipes"]))
        self.assertEqual(
            ["product-owner-release-2026-10-24"],
            evidence["knowledgeReview"]["releaseAuthorityIds"],
        )

    def test_release_preserves_missing_book_recipe_disclosure(self) -> None:
        release = prepare_source_reference_bundle(
            source_bundle=load_json(self.bundle_path),
            package_key="adult-baseline-book-reference-v1",
            food_snapshot=load_json(self.snapshot_path),
        )

        self.assertTrue(all(
            "Sách không đề cập công thức" in recipe["payload"]["sourceRecipeNote"]
            for recipe in release["recipes"]
        ))

    def test_rejects_disease_rules_even_with_product_owner_authorization(self) -> None:
        bundle = load_json(self.bundle_path)
        bundle["rules"] = [{"ruleId": "not-allowed"}]

        with self.assertRaisesRegex(ManualGraphError, "cannot contain disease rules"):
            self._build(bundle)

    def test_rejects_release_without_missing_book_recipe_disclosure(self) -> None:
        bundle = load_json(self.bundle_path)
        bundle["recipes"][0]["payload"].pop("sourceRecipeNote")

        with self.assertRaisesRegex(ManualGraphError, "sourceRecipeNote"):
            prepare_source_reference_bundle(
                source_bundle=bundle,
                package_key="adult-baseline-book-reference-v1",
                food_snapshot=load_json(self.snapshot_path),
            )


if __name__ == "__main__":
    unittest.main()
