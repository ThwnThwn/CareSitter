from __future__ import annotations

import math
from pathlib import Path
from typing import Protocol

from .corpus_freeze import validate_retrieval_corpus_binding
from .errors import ManualGraphError
from .jsonio import content_sha256, load_json, write_json
from .retrieval_artifacts import sign, verify
from .retrieval_eval import load_retrieval_chunks


class Encoder(Protocol):
    model: str
    digest: str
    dimension: int

    def encode(self, texts: list[str]) -> list[list[float]]: ...


def normalized(vector: list, dimension: int) -> list[float]:
    if (not isinstance(vector, list) or len(vector) != dimension
            or any(isinstance(v, bool) or not isinstance(v, (int, float))
                   or not math.isfinite(v) for v in vector)):
        raise ManualGraphError("embedding has invalid dimension or non-finite values")
    norm = math.sqrt(sum(v * v for v in vector))
    if not math.isfinite(norm) or norm <= 0:
        raise ManualGraphError("embedding must have a finite nonzero norm")
    return [v / norm for v in vector]


def embedding_text(chunk: dict) -> str:
    return "\n".join([*(chunk.get("headings") or []), chunk["text"]])


def model_identity(encoder: Encoder) -> dict:
    if not encoder.model or not encoder.digest or not 1 <= encoder.dimension <= 8192:
        raise ManualGraphError("embedding model identity is required")
    return {"model": encoder.model, "digest": encoder.digest, "dimension": encoder.dimension,
            "input_format": "headings_newline_text_v1"}


def build_embedding_index(*, chunks_path: Path, corpus_freeze: dict, encoder: Encoder,
                          cache_dir: Path) -> dict:
    validate_retrieval_corpus_binding(corpus_freeze=corpus_freeze, chunks_path=chunks_path)
    identity = model_identity(encoder)
    records = []
    for chunk in load_retrieval_chunks(chunks_path):
        text = embedding_text(chunk)
        input_hash = content_sha256(text)
        cache_key = content_sha256({"model": identity, "input": input_hash})
        cache_path = cache_dir / f"{cache_key}.json"
        if cache_path.exists():
            cached = load_json(cache_path)
            verify(cached, "embedding_cache")
            if cached.get("key") != cache_key:
                raise ManualGraphError("embedding cache key mismatch")
            vector = cached["vector"]
        else:
            vectors = encoder.encode([text])
            if len(vectors) != 1:
                raise ManualGraphError("encoder returned an unexpected vector count")
            vector = normalized(vectors[0], encoder.dimension)
            write_json(cache_path, sign({"schema_version": 1, "mode": "embedding_cache",
                                        "key": cache_key, "vector": vector}))
        normalized(vector, encoder.dimension)
        records.append({"chunk_id": chunk["chunk_id"], "input_sha256": input_hash, "vector": vector})
    return sign({"schema_version": 1, "mode": "local_embedding_index",
                 "corpus_freeze_sha256": corpus_freeze["content_sha256"],
                 "model": identity, "records": records})


def validate_embedding_index(index: dict, chunks: list[dict], corpus_freeze: dict,
                             encoder: Encoder) -> dict[str, list[float]]:
    verify(index, "local_embedding_index")
    if index.get("corpus_freeze_sha256") != corpus_freeze["content_sha256"]:
        raise ManualGraphError("embedding index belongs to a different corpus")
    if index.get("model") != model_identity(encoder):
        raise ManualGraphError("embedding model revision or dimension mismatch")
    expected = {c["chunk_id"]: content_sha256(embedding_text(c)) for c in chunks}
    vectors = {}
    for row in index.get("records", []):
        cid = row.get("chunk_id")
        if cid in vectors or cid not in expected or row.get("input_sha256") != expected[cid]:
            raise ManualGraphError("embedding index has duplicate, stale or ineligible chunks")
        vectors[cid] = normalized(row["vector"], encoder.dimension)
    if set(vectors) != set(expected):
        raise ManualGraphError("embedding index must contain every eligible chunk exactly once")
    return vectors
