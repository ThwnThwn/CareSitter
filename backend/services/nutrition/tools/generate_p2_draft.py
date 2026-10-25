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


RETRIEVED_ON = "2026-10-23"
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
    "TOFU_BOILED": ("đậu phụ", "3025002", "cooked"),
    "TOMATO_FRESH": ("cà chua", "4005", "raw"),
    "WATER_SPINACH_FRESH": ("rau muống", "4083", "raw"),
    # Ingredients from the hypertension reference menu on printed page 142.
    "RICE_NOODLE_READY": ("bánh phở", "1013", "cooked"),
    "BEEF_LEAN_RAW": ("thịt bò", "7003", "raw"),
    "SCALLION_FRESH": ("hành lá", "4038", "raw"),
    "PORK_LEAN_RAW": ("thịt lợn nạc", "7017", "raw"),
    "BOK_CHOY_FRESH": ("cải thìa", "4015", "raw"),
    "MALABAR_SPINACH_FRESH": ("mồng tơi", "4080", "raw"),
    "POMELO_FRESH": ("bưởi", "5001", "raw"),
    "PEANUT_OIL": ("dầu lạc", "6011", "raw"),
    "GRASS_CARP_RAW": ("cá trắm", "8029", "raw"),
    "CHICKEN_EGG_RAW": ("trứng gà", "9001", "raw"),
    "SAUROPUS_FRESH": ("rau ngót", "4086", "raw"),
    "MANDARIN_FRESH": ("quít", "5047", "raw"),
}

# The NIN lookup leaves structurally absent or trace nutrients blank for several
# animal foods, oils, vegetables and fruits. Local-demo calculations use zero for
# only these pinned fields and keep the normalization explicit in the source
# snapshot. The candidate remains blocked from release until data review.
PINNED_ZERO_NUTRIENTS = {
    "RICE_NOODLE_READY": {"fiber_g"},
    "BEEF_LEAN_RAW": {"carbohydrate_g", "fiber_g"},
    "SCALLION_FRESH": {"fat_g"},
    "PORK_LEAN_RAW": {"carbohydrate_g", "fiber_g"},
    "MALABAR_SPINACH_FRESH": {"fat_g"},
    "POMELO_FRESH": {"fat_g"},
    "PEANUT_OIL": {"protein_g", "carbohydrate_g", "fiber_g", "sodium_mg"},
    "GRASS_CARP_RAW": {"carbohydrate_g", "fiber_g"},
    "CHICKEN_EGG_RAW": {"fiber_g"},
    "SAUROPUS_FRESH": {"fat_g"},
    "MANDARIN_FRESH": {"fat_g"},
}

ANIMAL_INGREDIENTS = {"BEEF_LEAN_RAW", "PORK_LEAN_RAW", "GRASS_CARP_RAW", "CHICKEN_EGG_RAW"}

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
    # Exact main-meal groupings from Dinh dưỡng lâm sàng (2019), printed page
    # 142. This is intentionally the complete recipe scope for the current
    # knowledge test. The 15:00 milk is a snack and is not forced into the
    # three-meal product contract (breakfast/lunch/dinner).
    ("breakfast", "Phở thịt bò", [
        ("RICE_NOODLE_READY", 150), ("BEEF_LEAN_RAW", 35), ("SCALLION_FRESH", 10),
    ]),
    ("lunch", "Cơm thịt lợn rang, đậu phụ và rau", [
        ("RICE_WHITE_RAW", 60), ("PORK_LEAN_RAW", 50), ("TOFU_BOILED", 30),
        ("BOK_CHOY_FRESH", 200), ("PEANUT_OIL", 7), ("MALABAR_SPINACH_FRESH", 50),
        ("POMELO_FRESH", 200),
    ]),
    ("dinner", "Cơm cá trắm sốt cà chua, trứng và rau", [
        ("RICE_WHITE_RAW", 60), ("GRASS_CARP_RAW", 70), ("TOMATO_FRESH", 30),
        ("PEANUT_OIL", 10), ("CHICKEN_EGG_RAW", 25), ("WATER_SPINACH_FRESH", 200),
        ("SAUROPUS_FRESH", 50), ("MANDARIN_FRESH", 120),
    ]),
]

BOOK_MENU_PREPARATION = {
    "Phở thịt bò": [
        "Trụng bánh phở, làm chín thịt bò, thêm hành lá và chan nước dùng.",
        "Sách ghi nước dùng có tỷ lệ muối 1 g/100 ml nhưng không nêu lượng nước dùng của một khẩu phần; không tự suy diễn lượng này trong phép tính dinh dưỡng.",
    ],
    "Cơm thịt lợn rang, đậu phụ và rau": [
        "Nấu 60 g gạo thành khoảng 120 g cơm; rang 50 g thịt lợn nạc và trần 30 g đậu phụ.",
        "Xào 200 g cải thìa với 7 ml dầu ăn, nấu canh từ 50 g rau mồng tơi và dùng kèm 200 g bưởi.",
    ],
    "Cơm cá trắm sốt cà chua, trứng và rau": [
        "Nấu 60 g gạo thành khoảng 120 g cơm; rán 70 g cá trắm với 10 ml dầu ăn rồi sốt cùng 30 g cà chua; luộc 25 g trứng gà.",
        "Luộc 200 g rau muống, nấu canh từ 50 g rau ngót và dùng kèm 120 g quýt.",
    ],
}


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
            if output_key not in PINNED_ZERO_NUTRIENTS.get(concept_code, set()):
                raise RuntimeError(f"NIN entry {expected_code} is missing required nutrient {source_key}")
            value = 0
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
    if "GRASS_CARP_RAW" in ingredient_codes:
        result.append("FISH")
    if "CHICKEN_EGG_RAW" in ingredient_codes:
        result.append("EGG")
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
    is_book_menu = name in BOOK_MENU_PREPARATION
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
            "preparationSteps": BOOK_MENU_PREPARATION.get(name, [
                "Sơ chế nguyên liệu, nấu chín hoàn toàn theo dạng món trong tên bữa.",
                "Không thêm muối, nước mắm, nước tương, hạt nêm hoặc nước chấm vào bản công thức kỹ thuật này.",
            ]),
            "sources": ["VIEN_DINH_DUONG_2019", "VIETNAM_FOOD_COMPOSITION_2017"],
            "allergenDataComplete": True,
            "dietaryPatterns": [] if any(code in ANIMAL_INGREDIENTS for code, _ in items) else ["vegetarian"],
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
            *(["Đây là món từ thực đơn tham khảo trong sách; các giá trị trống được ghim về 0 theo PINNED_ZERO_NUTRIENTS và dầu ml đang dùng lượng số làm đại diện kỹ thuật để thử local."] if is_book_menu else []),
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
        "normalizationNotes": {
            "pinnedZeroNutrients": {key: sorted(value) for key, value in PINNED_ZERO_NUTRIENTS.items()},
            "scope": "Chỉ dùng cho local demo; mọi giá trị ghim về 0 vẫn chờ data review trước khi phát hành.",
        },
        "foods": list(food_by_code.values()),
    }
    source_path = sources / "nin-food-composition-2026-10-23.json"
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
        {"code": "FISH", "kind": "food_allergy", "aliases": ["Cá"], "version": 1},
        {"code": "EGG", "kind": "food_allergy", "aliases": ["Trứng", "Trứng gà"], "version": 1},
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
                "locator": "Mã thực phẩm và sáu chỉ số trên 100 g trong catalog/sources/nin-food-composition-2026-10-23.json",
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
