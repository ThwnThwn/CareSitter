from __future__ import annotations

import json
from pathlib import Path
import unicodedata


ROOT = Path(__file__).resolve().parents[1]


def entity(kind: str, name: str, span_id: str = "s1") -> dict:
    return {"type": kind, "name": name, "span_id": span_id}


def relation(kind: str, subject: str, object_: str, span_id: str = "s1") -> dict:
    return {"type": kind, "subject": subject, "object": object_, "span_id": span_id}


def claim(kind: str, subject: str, value: float, unit: str, span_id: str = "s1") -> dict:
    return {"type": kind, "subject": subject, "value": value, "unit": unit, "span_id": span_id}


def case(
    case_id: str,
    split: str,
    group: str,
    text: str | list[tuple[str, str]],
    *,
    tags: tuple[str, ...] = (),
    entities: tuple[dict, ...] = (),
    relations: tuple[dict, ...] = (),
    claims: tuple[dict, ...] = (),
    long: bool = False,
) -> dict:
    spans = [{"span_id": "s1", "text": text}] if isinstance(text, str) else [
        {"span_id": span_id, "text": value} for span_id, value in text
    ]
    if long:
        neutral = (
            " Ghi chú tổng hợp này chỉ mô tả cách ghi nhận thông tin trong một phiếu thử nghiệm. "
            "Người đọc cần phân biệt phần mô tả, phần số liệu và phần kết luận; không suy diễn thêm "
            "từ những câu không nêu trực tiếp thành phần hay giá trị. Các câu nền được lặp lại có chủ ý "
            "để kiểm tra ngữ cảnh dài, nhưng chúng không bổ sung dữ kiện dinh dưỡng mới."
        )
        spans[0]["text"] += neutral * 7
        tags = (*tags, "long")
    offsets = []
    cursor = 0
    for index, span in enumerate(spans):
        if index:
            cursor += 1
        start = cursor
        cursor += len(span["text"])
        offsets.append({"span_id": span["span_id"], "start": start, "end": cursor})
    return {
        "case_id": case_id,
        "split": split,
        "primary_group": group,
        "tags": sorted(set((group, *tags))),
        "spans": spans,
        "span_offsets": offsets,
        "gold": {
            "entities": list(entities),
            "relations": list(relations),
            "claims": list(claims),
        },
    }


def build_dev() -> list[dict]:
    return [
        case("dev-neg-01", "dev", "negation", "Súp bí đỏ không chứa lạc.",
             entities=(entity("Food", "súp bí đỏ"), entity("Allergen", "lạc"))),
        case("dev-num-01", "dev", "numeric", "Một phần cháo yến mạch cung cấp 180 kcal.",
             entities=(entity("Food", "cháo yến mạch"),), claims=(claim("ENERGY", "cháo yến mạch", 180, "kcal"),)),
        case("dev-num-02", "dev", "numeric", "Trong 100 g đậu xanh có 23 g protein.", tags=("direction_sensitive",),
             entities=(entity("Food", "đậu xanh"), entity("Nutrient", "protein")),
             relations=(relation("CONTAINS", "đậu xanh", "protein"),),
             claims=(claim("NUTRIENT_AMOUNT", "đậu xanh", 23, "g/100 g"),), long=True),
        case("dev-table-01", "dev", "table", [("h", "Thực phẩm | Năng lượng"), ("r1", "Khoai lang | 119 kcal")],
             tags=("direction_sensitive",), entities=(entity("Food", "khoai lang", "r1"),),
             claims=(claim("ENERGY", "khoai lang", 119, "kcal", "r1"),)),
        case("dev-alias-01", "dev", "alias", "Bắp còn được gọi là ngô.", tags=("direction_sensitive",),
             entities=(entity("Food", "bắp"), entity("Food", "ngô")),
             relations=(relation("ALIAS_OF", "bắp", "ngô"),)),
        case("dev-empty-01", "dev", "empty", "Phiếu được lập vào buổi sáng và sẽ được rà soát sau.")
    ]


def build_selection() -> list[dict]:
    nfd_food = unicodedata.normalize("NFD", "sữa chua")
    return [
        case("sel-neg-01", "selection", "negation", "Cháo cá không chứa đậu phộng.",
             entities=(entity("Food", "cháo cá"), entity("Allergen", "đậu phộng"))),
        case("sel-neg-02", "selection", "negation", "Bánh hấp không có sữa và không dành riêng cho tăng huyết áp.",
             tags=("combined", "direction_sensitive"), entities=(entity("Food", "bánh hấp"), entity("Allergen", "sữa"), entity("Condition", "tăng huyết áp")), long=True),
        case("sel-neg-03", "selection", "negation", "Cơm mềm không chứa mè; nhận xét trước đó về mè đã bị bác bỏ.",
             entities=(entity("Food", "cơm mềm"), entity("Allergen", "mè"))),
        case("sel-neg-04", "selection", "negation", "Canh rau không cung cấp số liệu natri trong tài liệu này.",
             entities=(entity("Food", "canh rau"), entity("Nutrient", "natri"))),

        case("sel-num-01", "selection", "numeric", "Một suất cơm gà cung cấp 520 kcal.",
             entities=(entity("Food", "cơm gà"),), claims=(claim("ENERGY", "cơm gà", 520, "kcal"),)),
        case("sel-num-02", "selection", "numeric", "Một bát phở rau có năng lượng 1460 kJ.",
             entities=(entity("Food", "phở rau"),), claims=(claim("ENERGY", "phở rau", 1460, "kJ"),), long=True),
        case("sel-num-03", "selection", "numeric", "Trong 100 g cá hấp có 19,5 g protein.", tags=("direction_sensitive",),
             entities=(entity("Food", "cá hấp"), entity("Nutrient", "protein")),
             relations=(relation("CONTAINS", "cá hấp", "protein"),),
             claims=(claim("NUTRIENT_AMOUNT", "cá hấp", 19.5, "g/100 g"),)),
        case("sel-num-04", "selection", "numeric", f"Trong 100 g {nfd_food} có 3,2 g protein.", tags=("direction_sensitive", "unicode_nfd"),
             entities=(entity("Food", "sữa chua"), entity("Nutrient", "protein")),
             relations=(relation("CONTAINS", "sữa chua", "protein"),),
             claims=(claim("NUTRIENT_AMOUNT", "sữa chua", 3.2, "g/100 g"),)),
        case("sel-num-05", "selection", "numeric", "Một khẩu phần súp nấm chứa 320 mg natri.", tags=("direction_sensitive",),
             entities=(entity("Food", "súp nấm"), entity("Nutrient", "natri")),
             relations=(relation("CONTAINS", "súp nấm", "natri"),),
             claims=(claim("SODIUM_AMOUNT", "súp nấm", 320, "mg"),), long=True),
        case("sel-num-06", "selection", "numeric", "Nước dùng có 1,2 g muối trong mỗi khẩu phần; không tự đổi thành natri.", tags=("combined", "direction_sensitive"),
             entities=(entity("Food", "nước dùng"), entity("Nutrient", "muối"), entity("Nutrient", "natri")),
             relations=(relation("CONTAINS", "nước dùng", "muối"),),
             claims=(claim("SALT_EQUIVALENT", "nước dùng", 1.2, "g"),)),

        case("sel-table-01", "selection", "table", [("h", "Món | Năng lượng"), ("r1", "Bún bí đỏ | 210 kcal")],
             entities=(entity("Food", "bún bí đỏ", "r1"),), claims=(claim("ENERGY", "bún bí đỏ", 210, "kcal", "r1"),)),
        case("sel-table-02", "selection", "table", [("h", "Món | Chất | Lượng"), ("r1", "Đậu hũ hấp | protein | 8 g/100 g")], tags=("combined", "direction_sensitive"),
             entities=(entity("Food", "đậu hũ hấp", "r1"), entity("Nutrient", "protein", "r1")),
             relations=(relation("CONTAINS", "đậu hũ hấp", "protein", "r1"),),
             claims=(claim("NUTRIENT_AMOUNT", "đậu hũ hấp", 8, "g/100 g", "r1"),), long=True),
        case("sel-table-03", "selection", "table", [("h", "Món | Natri"), ("r1", "Cháo sen | 95 mg")], tags=("direction_sensitive",),
             entities=(entity("Food", "cháo sen", "r1"), entity("Nutrient", "natri", "r1")),
             relations=(relation("CONTAINS", "cháo sen", "natri", "r1"),),
             claims=(claim("SODIUM_AMOUNT", "cháo sen", 95, "mg", "r1"),)),

        case("sel-alias-01", "selection", "alias", "Bắp là tên gọi khác của ngô.", tags=("direction_sensitive",),
             entities=(entity("Food", "bắp"), entity("Food", "ngô")), relations=(relation("ALIAS_OF", "bắp", "ngô"),)),
        case("sel-alias-02", "selection", "alias", "Đậu phộng còn được gọi là lạc.", tags=("direction_sensitive",),
             entities=(entity("Allergen", "đậu phộng"), entity("Allergen", "lạc")), relations=(relation("ALIAS_OF", "đậu phộng", "lạc"),)),
        case("sel-alias-03", "selection", "alias", "Vitamin C là tên thường dùng của acid ascorbic.", tags=("direction_sensitive",),
             entities=(entity("Nutrient", "vitamin C"), entity("Nutrient", "acid ascorbic")), relations=(relation("ALIAS_OF", "vitamin C", "acid ascorbic"),)),

        case("sel-amb-01", "selection", "ambiguous", "Lan ghi về cháo và súp. Món đó chứa sắt, nhưng không rõ 'món đó' là món nào.",
             entities=(entity("Food", "cháo"), entity("Food", "súp"), entity("Nutrient", "sắt"))),
        case("sel-amb-02", "selection", "ambiguous", "Hai món cá hấp và đậu hũ được nhắc tới. Nó có 12 g protein nhưng đại từ không có tiền ngữ rõ.",
             entities=(entity("Food", "cá hấp"), entity("Food", "đậu hũ"), entity("Nutrient", "protein"))),
        case("sel-empty-01", "selection", "empty", "Tài liệu được đánh số trang và lưu trong tủ hồ sơ vào chiều thứ hai."),
        case("sel-empty-02", "selection", "empty", "Nhân viên đã kiểm tra kiểu chữ, màu nền và thời gian cập nhật của biểu mẫu.")
    ]


def build_holdout() -> list[dict]:
    return [
        case("hold-neg-01", "holdout", "negation", "Cháo hạt sen không chứa trứng.", entities=(entity("Food", "cháo hạt sen"), entity("Allergen", "trứng"))),
        case("hold-neg-02", "holdout", "negation", "Canh củ không có lạc và không nêu số liệu muối.", tags=("combined",),
             entities=(entity("Food", "canh củ"), entity("Allergen", "lạc"), entity("Nutrient", "muối"))),
        case("hold-num-01", "holdout", "numeric", "Một phần mì rau cung cấp 330 kcal.",
             entities=(entity("Food", "mì rau"),), claims=(claim("ENERGY", "mì rau", 330, "kcal"),), long=True),
        case("hold-num-02", "holdout", "numeric", "Trong 100 g tôm hấp có 21 g protein.", tags=("direction_sensitive",),
             entities=(entity("Food", "tôm hấp"), entity("Nutrient", "protein")), relations=(relation("CONTAINS", "tôm hấp", "protein"),),
             claims=(claim("NUTRIENT_AMOUNT", "tôm hấp", 21, "g/100 g"),)),
        case("hold-num-03", "holdout", "numeric", "Một chén cháo nấm chứa 180\u00a0mg natri.", tags=("direction_sensitive", "unicode_nbsp"),
             entities=(entity("Food", "cháo nấm"), entity("Nutrient", "natri")), relations=(relation("CONTAINS", "cháo nấm", "natri"),),
             claims=(claim("SODIUM_AMOUNT", "cháo nấm", 180, "mg"),)),
        case("hold-table-01", "holdout", "table", [("h", "Món | Năng lượng"), ("r1", "Cơm bí | 245 kcal")],
             entities=(entity("Food", "cơm bí", "r1"),), claims=(claim("ENERGY", "cơm bí", 245, "kcal", "r1"),)),
        case("hold-table-02", "holdout", "table", [("h", "Món | Chất | Lượng"), ("r1", "Cá kho nhạt | natri | 205 mg")], tags=("direction_sensitive",),
             entities=(entity("Food", "cá kho nhạt", "r1"), entity("Nutrient", "natri", "r1")),
             relations=(relation("CONTAINS", "cá kho nhạt", "natri", "r1"),),
             claims=(claim("SODIUM_AMOUNT", "cá kho nhạt", 205, "mg", "r1"),), long=True),
        case("hold-alias-01", "holdout", "alias", "Muối ăn còn được gọi ngắn là muối.", tags=("direction_sensitive",),
             entities=(entity("Nutrient", "muối ăn"), entity("Nutrient", "muối")), relations=(relation("ALIAS_OF", "muối ăn", "muối"),)),
        case("hold-alias-02", "holdout", "alias", "Bắp và ngô là hai tên của cùng một thực phẩm; bắp là tên gọi khác của ngô.", tags=("direction_sensitive",),
             entities=(entity("Food", "bắp"), entity("Food", "ngô")), relations=(relation("ALIAS_OF", "bắp", "ngô"),)),
        case("hold-amb-01", "holdout", "ambiguous", "Bảng nhắc canh cá và cháo cá. Món này có kẽm, nhưng câu không chỉ rõ món nào.",
             entities=(entity("Food", "canh cá"), entity("Food", "cháo cá"), entity("Nutrient", "kẽm"))),
        case("hold-empty-01", "holdout", "empty", "Cuộc họp bắt đầu lúc tám giờ và kết thúc sau khi biên bản được ký."),
        case("hold-empty-02", "holdout", "empty", "Bản in thử dùng khổ giấy A4, lề đều và số trang đặt ở cuối.")
    ]


def main() -> int:
    fixtures = ROOT / "fixtures"
    fixtures.mkdir(parents=True, exist_ok=True)
    for split, cases in (
        ("dev", build_dev()),
        ("selection", build_selection()),
        ("holdout", build_holdout()),
    ):
        payload = {"schema_version": 1, "split": split, "cases": cases}
        target = fixtures / f"{split}.json"
        target.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
