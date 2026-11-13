from copy import deepcopy
import csv
import json
from pathlib import Path
import tempfile
import unittest

from test_catalog_authoring import _profile, _draft, _snapshot, _decisions
from nutrition_knowledge_manual.catalog_authoring import prepare_catalog_candidate, finalize_catalog_candidate
from nutrition_knowledge_manual.catalog_review import empty_catalog_review
from nutrition_knowledge_manual.catalog_review_sheets import export_sheet, import_sheet, main
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import write_json, content_sha256


class CatalogReviewSheetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.candidate = prepare_catalog_candidate(profile=_profile(), draft=_draft(), food_snapshot=_snapshot(),
                                                   input_file_sha256=_profile()["input_file_sha256"])
        self.manifest = self.candidate["manifest"]
        self.bundle = self.candidate["bundle"]
        self.evidence = self.candidate["evidence"]
        self.audit = self.root / "catalog-audit.csv"
        fields = ["catalog", "recipeVersionId", "name", "mealType", "eligible", "AllergenDataComplete",
                  "ingredients", "allergens", "preparationSteps", "sourceRecipeNote"]
        with self.audit.open("w", encoding="utf-8-sig", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=fields)
            writer.writeheader()
            for recipe in self.bundle["recipes"]:
                p = recipe["payload"]
                writer.writerow({"catalog": self.bundle["packageKey"], "recipeVersionId": p["versionId"],
                                 "name": p["name"], "mealType": p["mealType"], "eligible": "True",
                                 "AllergenDataComplete": str(p.get("allergenDataComplete", False)),
                                 **{k: json.dumps(p.get(k, [])) for k in ("ingredients", "allergens", "preparationSteps")},
                                 "sourceRecipeNote": p.get("sourceRecipeNote") or ""})
        self.ledger = empty_catalog_review(self.manifest)

    def export(self, role="data_steward"):
        return export_sheet(self.manifest, self.bundle, self.evidence, self.audit, role)

    def apply(self, sheet, ledger=None, role="data_steward"):
        return import_sheet(self.manifest, self.bundle, self.evidence, self.audit, role, sheet, ledger or self.ledger)

    def test_empty_sheet_preserves_pending_and_all_composition(self):
        sheet = self.export()
        self.assertEqual(self.ledger, self.apply(sheet))
        self.assertTrue(all(r["decision"] == "" and r["comment"] == "" and r["reviewer_id"] == "" for r in sheet["rows"]))
        for row in sheet["rows"]:
            self.assertIn("ingredients", row["recipe"]["payload"])
            self.assertIn("AllergenDataComplete", row["audit"])

    def test_roles_merge_idempotently_and_do_not_finalize_without_clinical(self):
        sheet = self.export()
        for row in sheet["rows"]:
            row.update(decision="approved", reviewer_id="synthetic-data", comment="Synthetic test only")
        data = self.apply(sheet)
        self.assertEqual(data, self.apply(sheet, data))
        with self.assertRaises(ManualGraphError):
            finalize_catalog_candidate(profile=_profile(), candidate_manifest=self.manifest,
                candidate_bundle=self.bundle, candidate_evidence=self.evidence, decisions=data)
        clinical = self.export("dietitian")
        clinical["rows"][0].update(decision="rejected", reviewer_id="synthetic-clinical", comment="Synthetic reject")
        merged = self.apply(clinical, data, "dietitian")
        self.assertEqual("rejected", merged["decisions"][0]["clinical_review"]["decision"])
        self.assertEqual(data["decisions"][0]["data_review"], merged["decisions"][0]["data_review"])

    def test_tampering_duplicates_wrong_roles_missing_fields_and_stale_audit_rejected(self):
        for mutation in (lambda s: s.update(reviewer_role="physician"),
                         lambda s: s["rows"][0].update(candidate_sha256="0" * 64),
                         lambda s: s["rows"][0]["recipe"]["payload"].update(name="Changed"),
                         lambda s: s["rows"].append(deepcopy(s["rows"][0])),
                         lambda s: s["rows"][0].update(decision="approved"),
                         lambda s: s["rows"][0].update(decision="yes", reviewer_id="test", comment="test")):
            sheet = self.export()
            mutation(sheet)
            with self.assertRaises(ManualGraphError):
                self.apply(sheet)
        sheet = self.export()
        self.audit.write_text(self.audit.read_text(encoding="utf-8-sig").replace("Synthetic", "Changed"), encoding="utf-8")
        with self.assertRaises(ManualGraphError):
            self.apply(sheet)

    def test_conflicting_existing_review_is_rejected(self):
        sheet = self.export()
        sheet["rows"][0].update(decision="approved", reviewer_id="synthetic-data", comment="Test")
        ledger = self.apply(sheet)
        sheet["rows"][0]["decision"] = "rejected"
        with self.assertRaises(ManualGraphError):
            self.apply(sheet, ledger)

    def test_one_recipe_without_clinical_review_blocks_finalization_even_with_final_approval(self):
        ledger = _decisions(self.candidate)  # Synthetic test approvals only.
        ledger["decisions"][0]["clinical_review"] = None
        ledger["content_sha256"] = content_sha256({k: v for k, v in ledger.items() if k != "content_sha256"})
        with self.assertRaisesRegex(ManualGraphError, "clinical"):
            finalize_catalog_candidate(profile=_profile(), candidate_manifest=self.manifest,
                candidate_bundle=self.bundle, candidate_evidence=self.evidence, decisions=ledger)

    def test_cli_exports_and_imports_without_overwriting_or_mutating_inputs(self):
        args = []
        for name, value in (("candidate-manifest", self.manifest), ("candidate-bundle", self.bundle), ("candidate-evidence", self.evidence)):
            path = self.root / (name + ".json")
            write_json(path, value)
            args += ["--" + name, str(path)]
        args += ["--audit-csv", str(self.audit), "--role", "physician"]
        sheet = self.root / "sheet.json"
        self.assertEqual(0, main(["export", *args, "--output", str(sheet)]))
        self.assertEqual(2, main(["export", *args, "--output", str(sheet)]))
        ledger = self.root / "ledger.json"
        write_json(ledger, self.ledger)
        before = ledger.read_bytes()
        self.assertEqual(0, main(["import", *args, "--sheet", str(sheet), "--ledger", str(ledger), "--output", str(self.root / "result.json")]))
        self.assertEqual(before, ledger.read_bytes())
        self.assertEqual(2, main(["export", *args, "--output", str(self.root / "catalog/drafts/form.json")]))
