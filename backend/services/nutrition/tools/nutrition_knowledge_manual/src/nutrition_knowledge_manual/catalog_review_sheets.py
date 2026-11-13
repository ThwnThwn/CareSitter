"""Local catalog review forms bound to candidates and the WP2 CatalogAudit CSV.

Run with python -m nutrition_knowledge_manual.catalog_review_sheets --help.
This module never connects to a database or publishes content.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import csv
import json
from pathlib import Path

from .catalog_review import (
    DATA_REVIEW_ROLES, CLINICAL_REVIEW_ROLES, record_recipe_review,
    validate_candidate_manifest, validate_catalog_review_ledger,
)
from .errors import ManualGraphError
from .review_policy import DEFAULT, check, metadata, add_argument
from .jsonio import content_sha256, file_sha256, load_json, serialized_json_bytes

ROLES = DATA_REVIEW_ROLES | CLINICAL_REVIEW_ROLES
EDITABLE = {"decision", "reviewer_id", "comment", "resolutions"}


def _csv_text(value: str) -> str:
    return "'" + value if value.lstrip()[:1] in {"=", "+", "-", "@"} else value


def export_sheet(manifest: dict, bundle: dict, evidence: dict, audit_csv: Path, role: str, review_policy=DEFAULT) -> dict:
    check(review_policy, evidence, role=role)
    if role not in ROLES:
        raise ManualGraphError("unsupported catalog reviewer role")
    candidates = validate_candidate_manifest(manifest)
    for key, artifact in (("candidate_bundle", bundle), ("candidate_evidence", evidence)):
        if manifest.get("artifacts", {}).get(key, {}).get("content_sha256") != content_sha256(artifact):
            raise ManualGraphError("candidate artifact hash mismatch")
    recipes = {r["payload"]["versionId"]: r for r in bundle["recipes"]}
    facts = {r["recipeVersionId"]: r for r in evidence["recipes"]}
    with audit_csv.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        columns = {"catalog", "recipeVersionId", "name", "mealType", "eligible", "AllergenDataComplete",
                   "ingredients", "allergens", "preparationSteps", "sourceRecipeNote"}
        if reader.fieldnames is None or set(reader.fieldnames) != columns or len(reader.fieldnames) != len(columns):
            raise ManualGraphError("expected the CatalogAudit CSV schema")
        audit_rows = list(reader)
        if any(set(row) != columns for row in audit_rows):
            raise ManualGraphError("unexpected catalog audit columns")
    audit = {r["recipeVersionId"]: r for r in audit_rows}
    if (len(recipes) != len(bundle["recipes"]) or len(facts) != len(evidence["recipes"])
            or len(audit) != len(audit_rows)
            or set(recipes) != set(candidates) or set(facts) != set(candidates)
            or set(audit) != set(candidates)):
        raise ManualGraphError("candidate and audit must contain every recipe exactly once")
    rows = []
    for version_id in sorted(candidates):
        recipe, fact, row = recipes[version_id], facts[version_id], audit[version_id]
        if content_sha256({"recipe": recipe, "evidence": fact}) != candidates[version_id]:
            raise ManualGraphError("stale recipe candidate hash")
        payload = recipe["payload"]
        expected = {"catalog": bundle["packageKey"], "name": payload["name"],
                    "mealType": payload["mealType"], "sourceRecipeNote": payload.get("sourceRecipeNote") or ""}
        if any(row.get(k) != _csv_text(v) for k, v in expected.items()):
            raise ManualGraphError("audit metadata differs from candidate")
        if row.get("AllergenDataComplete", "").lower() != str(payload.get("allergenDataComplete", False)).lower():
            raise ManualGraphError("audit completeness label differs from candidate")
        for column in ("ingredients", "allergens", "preparationSteps"):
            if json.loads(row[column]) != payload.get(column, []):
                raise ManualGraphError("audit composition differs from candidate")
        rows.append({"recipe_version_id": version_id, "candidate_sha256": candidates[version_id],
                     "recipe": deepcopy(recipe), "evidence": deepcopy(fact), "audit": row,
                     "decision": "", "reviewer_id": "", "comment": "", "resolutions": []})
    return {**metadata(review_policy), "schema_version": 1, "candidate_manifest_sha256": manifest["content_sha256"],
            "audit_file_sha256": file_sha256(audit_csv), "reviewer_role": role,
            "instructions": "Chỉ điền decision (approved/rejected), reviewer_id, comment và resolutions. "
                            "Để trống nếu chưa duyệt. Không sửa dữ liệu món/hash/vai trò. "
                            "Đây là phiếu local, danh tính/chuyên môn phải được xác minh ngoài công cụ.",
            "rows": rows}


def import_sheet(manifest: dict, bundle: dict, evidence: dict, audit_csv: Path,
                 role: str, sheet: dict, ledger: dict, review_policy=DEFAULT) -> dict:
    check(review_policy, ledger, role=role)
    validate_catalog_review_ledger(manifest, ledger)
    expected = export_sheet(manifest, bundle, evidence, audit_csv, role, review_policy)
    immutable = deepcopy(sheet)
    rows = immutable.get("rows")
    if not isinstance(rows, list):
        raise ManualGraphError("invalid catalog review rows")
    for row in rows:
        if not isinstance(row, dict) or not EDITABLE <= row.keys():
            raise ManualGraphError("missing catalog review fields")
        row.update(decision="", reviewer_id="", comment="", resolutions=[])
    if immutable != expected:
        raise ManualGraphError("review form content, hash or role changed")
    result = deepcopy(ledger)
    slot = "data_review" if role in DATA_REVIEW_ROLES else "clinical_review"
    for row in sheet["rows"]:
        if (row["decision"] == "" and row["reviewer_id"] == ""
                and row["comment"] == "" and row["resolutions"] == []):
            continue
        if any(not isinstance(row[k], str) or not row[k].strip()
               for k in ("decision", "reviewer_id", "comment")):
            raise ManualGraphError("decision, reviewer_id and comment are required together")
        current = next(r for r in result["decisions"] if r["recipe_version_id"] == row["recipe_version_id"])
        proposed = record_recipe_review(
            candidate_manifest=manifest, ledger=result, recipe_version_id=row["recipe_version_id"],
            decision=row["decision"], reviewer_id=row["reviewer_id"], reviewer_role=role,
            comment=row["comment"], resolutions=row["resolutions"], review_policy=review_policy,
            reviewed_at_utc=current[slot]["reviewed_at_utc"] if current[slot] else None)
        if current[slot] is not None and proposed != result:
            raise ManualGraphError("conflicting existing review; resolve explicitly in the ledger workflow")
        # Never overwrite a resolution made by another role/reviewer silently.
        updated = next(r for r in proposed["decisions"] if r["recipe_version_id"] == row["recipe_version_id"])
        old_resolutions = {r["item"]: r for r in current["resolutions"]}
        if any(r["item"] in old_resolutions and r != old_resolutions[r["item"]]
               for r in updated["resolutions"]):
            raise ManualGraphError("conflicting existing resolution")
        result = proposed
    validate_catalog_review_ledger(manifest, result)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    add_argument(parser)
    parser.add_argument("command", choices=("export", "import"))
    for name in ("candidate-manifest", "candidate-bundle", "candidate-evidence", "audit-csv", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--role", choices=sorted(ROLES), required=True)
    parser.add_argument("--sheet", type=Path)
    parser.add_argument("--ledger", type=Path)
    args = parser.parse_args(argv)
    try:
        output = args.output.resolve()
        if any(a == "catalog" and b in {"drafts", "sources"}
               for a, b in zip([p.lower() for p in output.parts], [p.lower() for p in output.parts[1:]])):
            raise ManualGraphError("output cannot be inside catalog drafts or sources")
        inputs = [args.candidate_manifest, args.candidate_bundle, args.candidate_evidence, args.audit_csv,
                  args.sheet, args.ledger]
        if any(p and p.resolve() == output for p in inputs):
            raise ManualGraphError("output must not overwrite an input")
        common = (load_json(args.candidate_manifest), load_json(args.candidate_bundle),
                  load_json(args.candidate_evidence), args.audit_csv, args.role)
        if args.command == "export":
            result = export_sheet(*common, review_policy=args.review_policy)
        else:
            if not args.sheet or not args.ledger:
                raise ManualGraphError("import requires --sheet and --ledger")
            result = import_sheet(*common, load_json(args.sheet), load_json(args.ledger), review_policy=args.review_policy)
        output.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive create: a failed validation never changes the source ledger or an earlier receipt.
        with output.open("xb") as stream:
            stream.write(serialized_json_bytes(result))
        print(json.dumps({"ok": True, "output": str(output), "content_sha256": content_sha256(result)}))
        return 0
    except (ManualGraphError, OSError, ValueError, KeyError, TypeError):
        print(json.dumps({"ok": False, "error": "Invalid catalog form/input, conflicting review or unavailable output. No ledger applied."}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
