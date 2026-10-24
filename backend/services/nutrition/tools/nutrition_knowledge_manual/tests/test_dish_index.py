from copy import deepcopy
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[4]
sys.path.insert(0, str(ROOT / "src"))

from nutrition_knowledge_manual.dish_index import validate_dish_index
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import load_json


INDEX_PATH = (
    WORKSPACE
    / "backend/services/nutrition/catalog/sources"
    / "clinical-nutrition-2019-dish-index.candidate.json"
)


class DishIndexTests(unittest.TestCase):
    def test_repository_index_is_balanced_fail_closed_and_catalog_linked(self):
        result = validate_dish_index(load_json(INDEX_PATH), WORKSPACE)

        self.assertEqual(81, result["entry_count"])
        self.assertEqual({
            "source_verified": 77,
            "structured": 4,
        }, result["status_counts"])
        self.assertEqual({
            "main_dish": 35,
            "noodle_staple": 12,
            "porridge_medical_feed": 8,
            "snack_beverage": 6,
            "soup_vegetable": 20,
        }, result["category_counts"])
        self.assertEqual(12, result["linked_catalog_recipe_count"])
        self.assertEqual(4, result["linked_entry_recipe_count"])
        self.assertEqual({"complete": 8, "partial": 1, "unknown": 72}, result["quantity_counts"])
        self.assertEqual(50, result["promotion_counts"]["needs_quantity_review"])
        self.assertEqual(23, result["promotion_counts"]["needs_split"])
        self.assertEqual(4, result["promotion_counts"]["structured_demo"])
        self.assertFalse(result["production_publishable"])

    def test_duplicate_and_unverified_recipe_promotion_are_rejected(self):
        index = deepcopy(load_json(INDEX_PATH))
        index["entries"][1]["id"] = index["entries"][0]["id"]
        candidate = next(
            entry for entry in index["entries"]
            if entry["verificationStatus"] == "source_verified"
        )
        candidate["verificationStatus"] = "structured"
        candidate["matchedPdfPages"] = []
        candidate["sourceTitles"] = []
        candidate["evidenceQuotes"] = []
        candidate["recipeVersionIds"] = ["00000000-0000-0000-0000-000000000001"]

        with self.assertRaisesRegex(
            ManualGraphError,
            "duplicated.*requires at least one matched PDF page",
        ):
            validate_dish_index(index, WORKSPACE)

    def test_changed_book_or_catalog_digest_is_rejected(self):
        index = deepcopy(load_json(INDEX_PATH))
        index["source"]["fileSha256"] = "0" * 64
        index["linkedCatalog"]["fileSha256"] = "f" * 64

        with self.assertRaisesRegex(ManualGraphError, "fileSha256 does not match"):
            validate_dish_index(index, WORKSPACE)


if __name__ == "__main__":
    unittest.main()
