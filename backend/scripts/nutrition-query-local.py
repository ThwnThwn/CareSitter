"""Query the verified M4 corpus locally without claiming a reviewed release."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import unicodedata


REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend/services/nutrition/tools/nutrition_knowledge_manual/src"))

from nutrition_knowledge_manual.errors import ManualGraphError  # noqa: E402
from nutrition_knowledge_manual.jsonio import file_sha256, load_json  # noqa: E402
from nutrition_knowledge_manual.ollama_encoder import OllamaEncoder  # noqa: E402
from nutrition_knowledge_manual.retrieval_artifacts import code_identity, verify  # noqa: E402
from nutrition_knowledge_manual.retrieval_suite import create_suite  # noqa: E402


ARTIFACT = REPO / "backend/artifacts/nutrition-knowledge-local"
INVENTORY = ARTIFACT / "graphs/book-heading.repair-inventory.rev-20261104-r2.json"
CONFIG = REPO / "backend/services/nutrition/tools/nutrition_knowledge_manual/config/retrieval.graph.v2.json"


def _is_meal_suggestion(question: str) -> bool:
    plain = "".join(char for char in unicodedata.normalize("NFD", question.casefold())
                    if unicodedata.category(char) != "Mn").replace("đ", "d")
    return (any(verb in plain for verb in ("goi y", "de xuat", "len thuc don"))
            and any(noun in plain for noun in ("mon", "thuc don", "bua an")))


def _artifact_path(inventory: dict, kind: str) -> Path:
    entries = [item for item in inventory["files"] if item.get("kind") == kind]
    if len(entries) != 1:
        raise ManualGraphError(f"inventory must contain one {kind} file")
    path = (REPO / entries[0]["path"]).resolve()
    if not path.is_relative_to(REPO) or file_sha256(path) != entries[0]["sha256"]:
        raise ManualGraphError(f"inventory dependency changed: {kind}")
    return path


def _load_verified_inputs() -> tuple[Path, dict, dict]:
    inventory = load_json(INVENTORY)
    verify(inventory, "graph_repair_inventory")
    if inventory.get("code") != code_identity():
        raise ManualGraphError("retrieval code changed after inventory was created")
    for item in inventory["files"]:
        path = (REPO / item["path"]).resolve()
        if not path.is_relative_to(REPO) or file_sha256(path) != item["sha256"]:
            raise ManualGraphError(f"inventory dependency changed: {item['path']}")
    return (_artifact_path(inventory, "corpus_chunks"),
            load_json(_artifact_path(inventory, "corpus_freeze")),
            load_json(_artifact_path(inventory, "embedding_index")))


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Tra cứu prototype Nutrition M4 trên máy local")
    parser.add_argument("--question", required=True)
    parser.add_argument("--strategy", choices=("keyword", "vector", "hybrid"), default="hybrid")
    parser.add_argument("--top-k", type=int, default=5)
    args = parser.parse_args()
    if not 1 <= args.top_k <= 10:
        parser.error("--top-k must be between 1 and 10")
    if _is_meal_suggestion(args.question):
        print("Để gợi ý món theo dị ứng và hồ sơ, hãy dùng mục dinh dưỡng trong app CareSitter. "
              "Lệnh này chỉ tra cứu đoạn sách, không tạo thực đơn.")
        return 0
    try:
        chunks_path, freeze, index = _load_verified_inputs()
        encoder = OllamaEncoder("http://127.0.0.1:11434", index["model"]["digest"])
        chunks, retrievers, _ = create_suite(
            chunks_path=chunks_path, corpus_freeze=freeze, config=load_json(CONFIG),
            encoder=encoder, index=index,
        )
        hits = retrievers[args.strategy].search(args.question, top_k=args.top_k)
    except (ManualGraphError, OSError, KeyError, ValueError) as error:
        print(f"Không thể tra cứu local: {error}", file=sys.stderr)
        return 1

    by_id = {chunk["chunk_id"]: chunk for chunk in chunks}
    print(f"Prototype local | {args.strategy} | {len(hits)} kết quả | chưa qua review release")
    for rank, hit in enumerate(hits, 1):
        excerpt = " ".join(by_id[hit["chunk_id"]]["text"].split())
        print(f"\n{rank}. PDF trang {hit['pdf_page']}, trang sách {hit['printed_page']} "
              f"| điểm {hit['score']:.4f} | {hit['chunk_id']}")
        print(excerpt[:240] + ("…" if len(excerpt) > 240 else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
