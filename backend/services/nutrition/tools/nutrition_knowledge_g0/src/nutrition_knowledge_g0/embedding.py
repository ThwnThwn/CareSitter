from __future__ import annotations

import math
from pathlib import Path
import time
from typing import Any

from .errors import ContractError
from .jsonio import load_json, write_json
from .ollama import OllamaClient
from .scoring import percentile


SMOKE_DOCUMENTS = [
    "Một phần cháo nấm chứa 180 mg natri.",
    "Trong 100 g cá hấp có 19,5 g protein.",
    "Một suất cơm gà cung cấp 520 kcal.",
    "Bắp còn được gọi là ngô.",
    "Cháo cá không chứa đậu phộng.",
]
SMOKE_QUESTIONS = [
    ("Món nào có 180 mg natri?", 0),
    ("Thực phẩm nào có 19,5 g protein trên 100 g?", 1),
    ("Món nào cung cấp 520 kcal?", 2),
    ("Tên gọi khác của bắp là gì?", 3),
    ("Món nào không chứa đậu phộng?", 4),
]


def run_embedding_smoke(
    *, module_root: Path, output_path: Path, ollama: OllamaClient, repeats: int = 30
) -> dict[str, Any]:
    if output_path.exists():
        raise ContractError(f"Refusing to overwrite embedding report: {output_path}")
    config = load_json(module_root / "config" / "models.json")["embedding"]
    model = config["tag"]
    ollama.embed(model, ["khởi động mô hình embedding"])
    latencies: list[float] = []
    for index in range(repeats):
        started = time.perf_counter()
        ollama.embed(model, [f"Đo độ trễ embedding tiếng Việt lượt {index}."])
        latencies.append(time.perf_counter() - started)
    documents = ollama.embed(model, SMOKE_DOCUMENTS).get("embeddings", [])
    questions = ollama.embed(model, [item[0] for item in SMOKE_QUESTIONS]).get("embeddings", [])
    if len(documents) != len(SMOKE_DOCUMENTS) or len(questions) != len(SMOKE_QUESTIONS):
        raise ContractError("Ollama returned an unexpected embedding count")
    dimensions = {len(item) for item in [*documents, *questions]}
    if dimensions != {config["dimensions"]}:
        raise ContractError(f"Unexpected embedding dimensions: {sorted(dimensions)}")
    hits = 0
    queries: list[dict[str, Any]] = []
    for (question, expected), vector in zip(SMOKE_QUESTIONS, questions):
        ranking = sorted(
            range(len(documents)),
            key=lambda index: _cosine(vector, documents[index]),
            reverse=True,
        )
        matched = expected in ranking[:3]
        hits += int(matched)
        queries.append({"question": question, "expected_document": expected, "top_3": ranking[:3], "matched": matched})
    report = {
        "schema_version": 1,
        "model": model,
        "dimensions": next(iter(dimensions)),
        "repeat_count": repeats,
        "latency_p50_seconds": percentile(latencies, 0.50),
        "latency_p95_seconds": percentile(latencies, 0.95),
        "smoke_top3_hits": hits,
        "smoke_passed": hits >= 4,
        "queries": queries,
        "scope": "smoke only; retrieval quality remains a G3 concern",
    }
    write_json(output_path, report)
    return report


def _cosine(left: list[float], right: list[float]) -> float:
    numerator = sum(a * b for a, b in zip(left, right))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    return numerator / (left_norm * right_norm) if left_norm and right_norm else 0.0
