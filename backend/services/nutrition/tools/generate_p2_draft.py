"""Build the P2 technical catalog from a pinned subset of the official NIN food lookup.

The output is deliberately a technical draft. The release evidence keeps recipe and
rule review gaps unresolved, so catalog-tool release-check must reject publication
until a qualified reviewer signs the exact bundle digest.
"""

from __future__ import annotations

import hashlib
import json
import urllib.parse
import urllib.request
import uuid
from decimal import Decimal, ROUND_HALF_EVEN
from pathlib import Path


RETRIEVED_ON = "2026-10-16"
BOOK_SHA256 = "ABEA34B8A6A63E9EABD25F57141C18BA6AC31012C1D4A8DCC15F9BA68DC7F737"
PACKAGE_KEY = "adult-hypertension-p2-technical-draft"
NAMESPACE = uuid.UUID("da02b691-8293-40ed-8ed0-791825c1a62f")
SOURCE_PAGE = "https://viendinhduong.vn/vi/cong-cu-va-tien-ich/gia-tri-dinh-duong-thuc-pham"
API = "https://viendinhduong.vn/api/fe/foodNatunal/getPageFoodData?page=1&pageSize=50&name={}"
IMAGE_URLS = {
    "breakfast": "https://res.cloudinary.com/dq9xxhsmf/image/upload/CareSitter/Nutrition/demo/breakfast-illustration.jpg",
    "lunch": "https://res.cloudinary.com/dq9xxhsmf/image/upload/CareSitter/Nutrition/demo/lunch-illustration.jpg",
    "dinner": "https://res.cloudinary.com/dq9xxhsmf/image/upload/CareSitter/Nutrition/demo/dinner-illustration.jpg",
}
IMAGE_ALTS = {
    "breakfast": "Ảnh minh hoạ món ăn cho bữa sáng",
    "lunch": "Ảnh minh hoạ món ăn cho bữa trưa",
    "dinner": "Ảnh minh hoạ món ăn cho bữa tối",
}

NUTRIENT_KEYS = {
    "energy_kcal": ("energy", "kcal"),
    "protein_g": ("protein", "g"),
    "carbohydrate_g": ("carbohydrate-by-difference", "g"),
    "fat_g": ("total-lipid-fat", "g"),
    "fiber_g": ("fibre-total-dietary", "g"),
    "sodium_mg": ("na", "mg"),
}

FOODS = {
    "RICE_WHITE_RAW": ("gạo", "1004", "raw"),
    "MUNG_BEAN_DRY": ("đậu xanh hạt", "3010", "raw"),
    "SWEET_POTATO_BOILED": ("khoai lang", "2008002", "cooked"),
    "TOFU_BOILED": ("đậu phụ", "3025002", "cooked"),
    "BOK_CHOY_BOILED": ("cải thìa", "4015002", "cooked"),
    "SOYBEAN_DRY": ("đậu tương", "3007", "raw"),
    "PEANUT_DRY": ("lạc hạt", "3017", "raw"),
    "SESAME_DRY": ("vừng", "3020", "raw"),
    "TOMATO_FRESH": ("cà chua", "4005", "raw"),
    "WATER_SPINACH_FRESH": ("rau muống", "4083", "raw"),
    "CABBAGE_BOILED": ("cải bắp", "4010002", "cooked"),
    "CHAYOTE_FRESH": ("su su", "4098", "raw"),
    "ONION_FRESH": ("hành tây", "4039", "raw"),
}

# These concepts let structured profiles resolve common older-adult conditions.
# Only HYPERTENSION has a candidate rule. Every other condition remains unsupported
# and NutritionEligibilityPolicy must route the profile to professional guidance.
SEEDED_CONDITIONS = [
    ("TYPE_2_DIABETES", ["Đái tháo đường type 2", "Đái tháo đường típ 2", "Tiểu đường type 2", "Tiểu đường típ 2"]),
    ("DYSLIPIDEMIA", ["Rối loạn lipid máu", "Rối loạn mỡ máu", "Mỡ máu cao"]),
    ("OBESITY", ["Béo phì", "Thừa cân béo phì"]),
    ("OSTEOPOROSIS", ["Loãng xương"]),
    ("MALNUTRITION", ["Suy dinh dưỡng", "Nguy cơ suy dinh dưỡng"]),
    ("SARCOPENIA", ["Thiểu cơ", "Sarcopenia"]),
    ("GOUT", ["Gút", "Gout"]),
    ("KIDNEY_DISEASE", ["Bệnh thận", "Bệnh thận mạn", "Suy thận"]),
    ("HEART_FAILURE", ["Suy tim"]),
    ("STROKE", ["Tai biến mạch máu não", "Đột quỵ"]),
    ("CANCER", ["Ung thư"]),
]

RECIPES = [
    ("breakfast", "Cháo gạo tẻ đậu xanh", [("RICE_WHITE_RAW", 50), ("MUNG_BEAN_DRY", 20)]),
    ("breakfast", "Khoai lang luộc với đậu phụ và cải thìa", [("SWEET_POTATO_BOILED", 200), ("TOFU_BOILED", 60), ("BOK_CHOY_BOILED", 100)]),
    ("breakfast", "Cháo gạo tẻ đậu tương", [("RICE_WHITE_RAW", 50), ("SOYBEAN_DRY", 20)]),
    ("breakfast", "Cơm mềm lạc vừng và cà chua", [("RICE_WHITE_RAW", 50), ("PEANUT_DRY", 15), ("SESAME_DRY", 5), ("TOMATO_FRESH", 100)]),
    ("lunch", "Cơm đậu phụ, cải thìa và cà chua", [("RICE_WHITE_RAW", 60), ("TOFU_BOILED", 100), ("BOK_CHOY_BOILED", 200), ("TOMATO_FRESH", 50)]),
    ("lunch", "Cơm đậu xanh, bắp cải và su su", [("RICE_WHITE_RAW", 60), ("MUNG_BEAN_DRY", 30), ("CABBAGE_BOILED", 150), ("CHAYOTE_FRESH", 100)]),
    ("lunch", "Cơm đậu tương, rau muống và hành tây", [("RICE_WHITE_RAW", 60), ("SOYBEAN_DRY", 30), ("WATER_SPINACH_FRESH", 200), ("ONION_FRESH", 50)]),
    ("lunch", "Cơm lạc vừng, cải thìa và su su", [("RICE_WHITE_RAW", 60), ("PEANUT_DRY", 25), ("SESAME_DRY", 5), ("BOK_CHOY_BOILED", 150), ("CHAYOTE_FRESH", 100)]),
    ("dinner", "Cơm đậu phụ, bắp cải và su su", [("RICE_WHITE_RAW", 50), ("TOFU_BOILED", 100), ("CABBAGE_BOILED", 150), ("CHAYOTE_FRESH", 100)]),
    ("dinner", "Cơm đậu xanh, rau muống và cà chua", [("RICE_WHITE_RAW", 50), ("MUNG_BEAN_DRY", 30), ("WATER_SPINACH_FRESH", 200), ("TOMATO_FRESH", 50)]),
    ("dinner", "Khoai lang, đậu tương và cải thìa", [("SWEET_POTATO_BOILED", 250), ("SOYBEAN_DRY", 30), ("BOK_CHOY_BOILED", 150)]),
    ("dinner", "Cơm lạc vừng, bắp cải và hành tây", [("RICE_WHITE_RAW", 50), ("PEANUT_DRY", 25), ("SESAME_DRY", 5), ("CABBAGE_BOILED", 150), ("ONION_FRESH", 50)]),
    # Local-demo expansion: these combinations use only the same pinned food
    # snapshot and calculation contract as the original twelve recipes. They are
    # still technical candidates and do not bypass data or clinical review.
    ("breakfast", "Cháo gạo tẻ đậu phụ và cà chua", [("RICE_WHITE_RAW", 50), ("TOFU_BOILED", 80), ("TOMATO_FRESH", 80)]),
    ("breakfast", "Khoai lang luộc với đậu xanh", [("SWEET_POTATO_BOILED", 180), ("MUNG_BEAN_DRY", 25)]),
    ("breakfast", "Cháo gạo tẻ lạc vừng", [("RICE_WHITE_RAW", 45), ("PEANUT_DRY", 15), ("SESAME_DRY", 5)]),
    ("breakfast", "Khoai lang, đậu tương và bắp cải", [("SWEET_POTATO_BOILED", 180), ("SOYBEAN_DRY", 20), ("CABBAGE_BOILED", 100)]),
    ("lunch", "Cơm đậu phụ, rau muống và cà chua", [("RICE_WHITE_RAW", 60), ("TOFU_BOILED", 100), ("WATER_SPINACH_FRESH", 150), ("TOMATO_FRESH", 80)]),
    ("lunch", "Cơm đậu xanh, cải thìa và hành tây", [("RICE_WHITE_RAW", 60), ("MUNG_BEAN_DRY", 30), ("BOK_CHOY_BOILED", 150), ("ONION_FRESH", 50)]),
    ("lunch", "Cơm đậu tương, bắp cải và su su", [("RICE_WHITE_RAW", 60), ("SOYBEAN_DRY", 30), ("CABBAGE_BOILED", 150), ("CHAYOTE_FRESH", 100)]),
    ("lunch", "Cơm lạc vừng, rau muống và cà chua", [("RICE_WHITE_RAW", 60), ("PEANUT_DRY", 25), ("SESAME_DRY", 5), ("WATER_SPINACH_FRESH", 150), ("TOMATO_FRESH", 80)]),
    ("dinner", "Cơm đậu phụ, rau muống và su su", [("RICE_WHITE_RAW", 50), ("TOFU_BOILED", 100), ("WATER_SPINACH_FRESH", 150), ("CHAYOTE_FRESH", 100)]),
    ("dinner", "Cơm đậu xanh, cải thìa và cà chua", [("RICE_WHITE_RAW", 50), ("MUNG_BEAN_DRY", 30), ("BOK_CHOY_BOILED", 150), ("TOMATO_FRESH", 80)]),
    ("dinner", "Khoai lang, đậu phụ và bắp cải", [("SWEET_POTATO_BOILED", 250), ("TOFU_BOILED", 100), ("CABBAGE_BOILED", 150)]),
    ("dinner", "Cơm đậu tương, cải thìa và hành tây", [("RICE_WHITE_RAW", 50), ("SOYBEAN_DRY", 30), ("BOK_CHOY_BOILED", 150), ("ONION_FRESH", 50)]),
]


def stable_id(kind: str, key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{PACKAGE_KEY}:{kind}:{key}"))


def fetch_food(query: str, code: str) -> dict:
    url = API.format(urllib.parse.quote(query))
    request = urllib.request.Request(url, headers={"User-Agent": "CareSitter-P2-catalog-authoring/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    matches = [food for food in payload["data"] if str(food["code"]) == code]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one NIN entry for code {code}, found {len(matches)}")
    return matches[0]


def normalized_food(concept_code: str, query: str, expected_code: str, basis: str) -> dict:
    food = fetch_food(query, expected_code)
    raw_nutrients = {item["key"]: item for item in food["nutrition"]}
    nutrients = {}
    for output_key, (source_key, unit) in NUTRIENT_KEYS.items():
        value = food.get(source_key) if source_key == "energy" else raw_nutrients.get(source_key, {}).get("value")
        if value is None:
            raise RuntimeError(f"NIN entry {expected_code} is missing required nutrient {source_key}")
        nutrients[output_key] = {"value": value, "unit": unit, "sourceKey": source_key}
    return {
        "conceptCode": concept_code,
        "ninCode": expected_code,
        "nameVi": food["name_vi"],
        "nameEn": food.get("name_en"),
        "basis": basis,
        "perAmount": 100,
        "perUnit": "g",
        "nutrients": nutrients,
        "sourceLocator": f"{SOURCE_PAGE}; mã thực phẩm {expected_code}",
    }


def allergens(ingredient_codes: list[str]) -> list[str]:
    result = []
    if any(code in ingredient_codes for code in ("TOFU_BOILED", "SOYBEAN_DRY")):
        result.append("SOY")
    if "PEANUT_DRY" in ingredient_codes:
        result.append("PEANUT")
    if "SESAME_DRY" in ingredient_codes:
        result.append("SESAME")
    return result


def build_recipe(food_by_code: dict[str, dict], meal_type: str, name: str, items: list[tuple[str, int]]) -> tuple[dict, dict]:
    key = name.lower().replace(" ", "-")
    recipe_id = stable_id("recipe", key)
    version_id = stable_id("recipe-version", key)
    totals = {key: Decimal("0") for key in NUTRIENT_KEYS}
    formulas = {key: [] for key in NUTRIENT_KEYS}
    ingredients = []
    ingredient_evidence = []
    for code, amount in items:
        food = food_by_code[code]
        ingredients.append({"code": code, "name": food["nameVi"], "amount": amount, "unit": "g", "basis": food["basis"]})
        ingredient_evidence.append({
            "ingredientCode": code,
            "sourceId": "VIETNAM_FOOD_COMPOSITION_2017",
            "sourceLocator": food["sourceLocator"],
            "amountBasis": food["basis"],
            "nutrientsPer100G": {key: value["value"] for key, value in food["nutrients"].items()},
            "ediblePortionFactor": 1,
            "yieldFactor": 1,
        })
        for nutrient_key in NUTRIENT_KEYS:
            per_100 = food["nutrients"][nutrient_key]["value"]
            contribution = Decimal(str(per_100)) * Decimal(amount) / Decimal(100)
            totals[nutrient_key] += contribution
            formulas[nutrient_key].append(f"{code}: {amount} g × {per_100}/100")
    rounded = {key: float(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)) for key, value in totals.items()}
    recipe = {
        "recipeId": recipe_id,
        "version": 1,
        "payload": {
            "versionId": version_id,
            "name": name,
            "mealType": meal_type,
            "imageUrl": IMAGE_URLS[meal_type],
            "imageAlt": IMAGE_ALTS[meal_type],
            "servings": 1,
            "ingredients": ingredients,
            "allergens": allergens([code for code, _ in items]),
            "nutrients": rounded,
            "preparationSteps": [
                "Sơ chế nguyên liệu, nấu chín hoàn toàn theo dạng món trong tên bữa.",
                "Không thêm muối, nước mắm, nước tương, hạt nêm hoặc nước chấm vào bản công thức kỹ thuật này.",
            ],
            "sources": ["VIEN_DINH_DUONG_2019", "VIETNAM_FOOD_COMPOSITION_2017"],
            "allergenDataComplete": True,
            "dietaryPatterns": ["vegetarian"],
        },
    }
    nutrient_evidence = [{
        "key": nutrient_key,
        "value": rounded[nutrient_key],
        "unit": NUTRIENT_KEYS[nutrient_key][1],
        "method": "ingredient_sum_per_100g",
        "sourceIds": ["VIETNAM_FOOD_COMPOSITION_2017"],
        "calculation": " + ".join(formulas[nutrient_key]),
    } for nutrient_key in NUTRIENT_KEYS]
    evidence = {
        "recipeVersionId": version_id,
        "ingredients": ingredient_evidence,
        "nutrients": nutrient_evidence,
        "unresolvedItems": [
            "Công thức phối hợp từ nhóm món Việt Nam mới là bản nháp kỹ thuật; cần chuyên gia dinh dưỡng duyệt khẩu phần và cách chế biến.",
            "Chưa xác nhận hệ số hao hụt khi nấu cho toàn bộ công thức; số liệu dùng đúng basis của từng mục thực phẩm và hệ số 1.",
        ],
    }
    return recipe, evidence


def write_json(path: Path, value: object) -> bytes:
    data = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    drafts = root / "catalog" / "drafts"
    sources = root / "catalog" / "sources"
    food_by_code = {
        code: normalized_food(code, query, expected_code, basis)
        for code, (query, expected_code, basis) in FOODS.items()
    }
    source_snapshot = {
        "schemaVersion": 1,
        "sourceTitle": "Giá trị dinh dưỡng thực phẩm",
        "organization": "Viện Dinh dưỡng",
        "sourcePage": SOURCE_PAGE,
        "apiTemplate": API,
        "retrievedOn": RETRIEVED_ON,
        "basis": "Giá trị trên 100 g phần ăn được theo mục thực phẩm được chọn.",
        "foods": list(food_by_code.values()),
    }
    source_path = sources / "nin-food-composition-2026-10-16.json"
    write_json(source_path, source_snapshot)

    recipes, recipe_evidence = [], []
    for meal_type, name, items in RECIPES:
        recipe, evidence = build_recipe(food_by_code, meal_type, name, items)
        recipes.append(recipe)
        recipe_evidence.append(evidence)

    rule_id = stable_id("rule", "hypertension-sodium")
    rule_version_id = stable_id("rule-version", "hypertension-sodium")
    concepts = [
        {"code": "HYPERTENSION", "kind": "condition", "aliases": ["Tăng huyết áp", "Cao huyết áp"], "version": 1},
        *[{"code": code, "kind": "condition", "aliases": aliases, "version": 1} for code, aliases in SEEDED_CONDITIONS],
        {"code": "SOY", "kind": "food_allergy", "aliases": ["Đậu nành", "Đậu tương", "Đậu phụ"], "version": 1},
        {"code": "PEANUT", "kind": "food_allergy", "aliases": ["Lạc", "Đậu phộng"], "version": 1},
        {"code": "SESAME", "kind": "food_allergy", "aliases": ["Vừng", "Mè"], "version": 1},
    ] + [{"code": code, "kind": "ingredient", "aliases": [food["nameVi"]], "version": 1} for code, food in food_by_code.items()]
    bundle = {
        "schemaVersion": 1,
        "packageKey": PACKAGE_KEY,
        "supportedScopes": [{
            "code": "adult-hypertension-structured-v1",
            "population": "adult",
            "conditionCodes": ["HYPERTENSION"],
            "medicationPolicy": "reported_none_only",
            "blockedSpecialNeeds": ["KIDNEY_DISEASE", "DYSPHAGIA", "TUBE_FEEDING", "FLUID_RESTRICTION", "ELECTROLYTE_RESTRICTION"],
        }],
        "citations": [
            {
                "id": "VIEN_DINH_DUONG_2019",
                "title": "Dinh dưỡng lâm sàng",
                "organization": "Viện Dinh dưỡng",
                "year": 2019,
                "edition": "2019",
                "chapter": "Xây dựng chế độ ăn; Tăng huyết áp",
                "printedPages": "64-75; 131-143",
                "pdfPages": "65-76; 132-144",
                "locator": "Nguyên tắc tính khẩu phần và thực đơn ví dụ; công thức P2 là bản phối hợp kỹ thuật, không chép nguyên văn thực đơn.",
                "reference": "book/Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf",
                "verifiedOn": RETRIEVED_ON,
                "fileSha256": BOOK_SHA256,
            },
            {
                "id": "VIETNAM_FOOD_COMPOSITION_2017",
                "title": "Bảng thành phần thực phẩm Việt Nam 2017 - công cụ tra cứu trực tuyến",
                "organization": "Viện Dinh dưỡng",
                "year": 2017,
                "edition": "2017",
                "chapter": "Các mục thực phẩm được chụp trong source snapshot",
                "printedPages": None,
                "pdfPages": None,
                "locator": "Mã thực phẩm và sáu chỉ số trên 100 g trong catalog/sources/nin-food-composition-2026-10-16.json",
                "reference": SOURCE_PAGE,
                "verifiedOn": RETRIEVED_ON,
                "fileSha256": None,
            },
            {
                "id": "MOH_HTN_GUIDE_2010",
                "title": "Hướng dẫn chẩn đoán và điều trị tăng huyết áp",
                "organization": "Bộ Y tế - Cục Quản lý Khám, chữa bệnh",
                "year": 2010,
                "edition": "Quyết định 3192/QĐ-BYT",
                "chapter": "Thay đổi lối sống",
                "printedPages": None,
                "pdfPages": None,
                "locator": "Khuyến nghị giảm muối; tài liệu cũ nên rule vẫn chờ rà soát tính hiện hành.",
                "reference": "https://kcb.vn/phac-do/huong-dan-chan-doan-va-dieu-tri-tang-huyet-ap.html",
                "verifiedOn": RETRIEVED_ON,
                "fileSha256": None,
            },
        ],
        "concepts": concepts,
        "recipes": recipes,
        "rules": [{
            "ruleId": rule_id,
            "version": 1,
            "payload": {
                "versionId": rule_version_id,
                "conditionCode": "HYPERTENSION",
                "prerequisites": [
                    {"field": "conditionsStatus", "operator": "equals", "values": ["reported_present"], "evidenceSource": "health_profile", "unit": None, "maxAgeDays": None},
                    {"field": "medicationsStatus", "operator": "equals", "values": ["reported_none"], "evidenceSource": "health_profile", "unit": None, "maxAgeDays": None},
                    {"field": "feedingRoute", "operator": "equals", "values": ["oral"], "evidenceSource": "health_profile", "unit": None, "maxAgeDays": None},
                    {"field": "swallowingStatus", "operator": "equals", "values": ["normal"], "evidenceSource": "health_profile", "unit": None, "maxAgeDays": None},
                    {"field": "fluidRestriction", "operator": "equals", "values": ["none"], "evidenceSource": "health_profile", "unit": None, "maxAgeDays": None},
                    {"field": "electrolyteRestriction", "operator": "equals", "values": ["none"], "evidenceSource": "health_profile", "unit": None, "maxAgeDays": None},
                ],
                "excludedIngredients": [],
                "dailyMaximums": {"sodium_mg": 2000},
                "sources": ["VIEN_DINH_DUONG_2019", "MOH_HTN_GUIDE_2010"],
            },
        }],
    }
    bundle_path = drafts / "adult-hypertension-p2.bundle.json"
    bundle_bytes = write_json(bundle_path, bundle)
    digest = hashlib.sha256(bundle_bytes).hexdigest()
    evidence = {
        "schemaVersion": 1,
        "packageKey": PACKAGE_KEY,
        "bundleFileSha256": digest,
        "contentStatus": "technical_draft",
        "calculationBasis": "Cộng từng nguyên liệu theo khối lượng ghi trong công thức và giá trị trên 100 g từ snapshot Viện Dinh dưỡng; làm tròn 2 chữ số thập phân.",
        "requiredNutrients": list(NUTRIENT_KEYS),
        "recipes": recipe_evidence,
        "rules": [{
            "ruleVersionId": rule_version_id,
            "sourceIds": ["VIEN_DINH_DUONG_2019", "MOH_HTN_GUIDE_2010"],
            "sourceLocator": "Dinh dưỡng lâm sàng, trang in 138-143; hướng dẫn tăng huyết áp, mục thay đổi lối sống.",
            "unresolvedItems": [
                "Ngưỡng sodium_mg=2000 cần chuyên gia dinh dưỡng xác nhận cho phạm vi sản phẩm và rà soát với hướng dẫn hiện hành.",
                "Sách có chỗ diễn đạt đơn vị natri/muối không nhất quán; không tự sửa hay suy diễn thành rule phát hành.",
            ],
        }],
        "clinicalReview": None,
    }
    evidence_path = drafts / "adult-hypertension-p2.evidence.json"
    write_json(evidence_path, evidence)
    print(json.dumps({
        "bundle": str(bundle_path),
        "evidence": str(evidence_path),
        "sourceSnapshot": str(source_path),
        "bundleFileSha256": digest,
        "recipes": len(recipes),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
