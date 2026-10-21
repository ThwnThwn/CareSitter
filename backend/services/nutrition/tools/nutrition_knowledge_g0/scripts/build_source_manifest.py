from __future__ import annotations

import hashlib
import json
import mimetypes
from pathlib import Path


MODULE_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = Path(__file__).resolve().parents[6]
CHECKED_AT = "2026-10-20T00:00:00Z"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def record(
    source_id: str,
    path: Path,
    title: str,
    status: str,
    *,
    author: str = "",
    edition: str = "",
    year: int | None = None,
) -> dict:
    sha256 = digest(path)
    relative = path.relative_to(WORKSPACE_ROOT).as_posix()
    synthetic = status == "synthetic"
    return {
        "source_id": source_id,
        "revision_id": f"{source_id}@sha256:{sha256[:16]}",
        "title": title,
        "author": author,
        "edition": edition,
        "year": year,
        "path": relative,
        "sha256": sha256,
        "byte_size": path.stat().st_size,
        "mime": mimetypes.guess_type(path.name)[0] or "application/octet-stream",
        "language": "vi",
        "rights_status": status,
        "allowed_uses": ["metadata", "local_index", "local_query", "internal_citation"] if synthetic else ["metadata"],
        "rights_evidence": "Project-authored synthetic benchmark fixture; contains no book text or patient data." if synthetic else "",
        "checked_by": "CareSitter engineering",
        "checked_at_utc": CHECKED_AT,
    }


def main() -> int:
    sources = [
        record(f"g0-{split}-fixtures", MODULE_ROOT / "fixtures" / f"{split}.json", f"G0 {split} synthetic fixtures", "synthetic")
        for split in ("dev", "selection", "holdout")
    ]
    sources.extend([
        record("book-an-gi-khong-chet-sample", WORKSPACE_ROOT / "book" / "An_gi_khong_chet_NXB_Tre_2022_official_sample.html", "Ăn gì không chết — official sample metadata", "unverified", edition="NXB Trẻ", year=2022),
        record("book-che-do-an-truong-tho-product-page", WORKSPACE_ROOT / "book" / "Che_do_an_truong_tho_Medinsights_product_page_2026-10-16.html", "Chế độ ăn trường thọ — product metadata page", "unverified", edition="MedInsights"),
        record("book-dinh-duong-lam-sang-2019", WORKSPACE_ROOT / "book" / "Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf", "Dinh dưỡng lâm sàng", "unverified", author="Viện Dinh dưỡng", year=2019),
        record("nutrition-p2-draft-bundle", WORKSPACE_ROOT / "backend" / "services" / "nutrition" / "catalog" / "drafts" / "adult-hypertension-p2.bundle.json", "Nutrition P2 draft catalog bundle", "unverified"),
        record("nutrition-p2-draft-evidence", WORKSPACE_ROOT / "backend" / "services" / "nutrition" / "catalog" / "drafts" / "adult-hypertension-p2.evidence.json", "Nutrition P2 draft evidence sidecar", "unverified"),
    ])
    target = MODULE_ROOT / "config" / "source-manifest.json"
    target.write_text(json.dumps({"schema_version": 1, "sources": sources}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
