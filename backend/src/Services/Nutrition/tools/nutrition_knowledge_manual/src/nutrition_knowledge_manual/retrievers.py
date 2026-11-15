from __future__ import annotations

import math
from typing import Protocol

from .embedding_index import Encoder, normalized, validate_embedding_index
from .errors import ManualGraphError
from .keyword_retriever import _LexicalIndex


class Retriever(Protocol):
    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> list[dict]: ...


def validate_query(question: str, top_k: int, filters: dict | None) -> dict:
    if not isinstance(question, str) or len(question) > 500:
        raise ManualGraphError("retrieval question must be text of at most 500 characters")
    if isinstance(top_k, bool) or not isinstance(top_k, int) or not 1 <= top_k <= 100:
        raise ManualGraphError("retrieval top_k must be between 1 and 100")
    filters = filters or {}
    if not isinstance(filters, dict) or set(filters) - {"source_revision_id"}:
        raise ManualGraphError("unsupported retrieval filter")
    return filters


def accepts(chunk: dict, filters: dict) -> bool:
    return all(chunk.get(key) == value for key, value in filters.items())


def cited_hit(chunk: dict, score: float, strategy: str, provenance: dict) -> dict:
    return {**{k: chunk.get(k) for k in ("chunk_id", "source_revision_id", "source_locator",
                                       "pdf_page", "printed_page")},
            "score": round(score, 8), "strategy": strategy, "provenance": provenance}


def threshold(value: float, minimum: float, maximum: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not minimum <= value <= maximum:
        raise ManualGraphError("invalid retrieval threshold")
    return value


class KeywordRetriever:
    def __init__(self, chunks: list[dict], minimum_score: float = 0.0):
        self._index = _LexicalIndex(chunks)
        self._chunks = {c["chunk_id"]: c for c in chunks}
        self._minimum = threshold(minimum_score, 0, 10000)

    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> list[dict]:
        filters = validate_query(question, top_k, filters)
        hits = self._index.search(question, top_k=len(self._chunks))
        return [cited_hit(self._chunks[h["chunk_id"]], h["score"], "keyword",
                          {"method": "bm25_fielded_unicode_v1"}) for h in hits
                if h["score"] >= self._minimum and accepts(h, filters)][:top_k]


class EmbeddingRetriever:
    def __init__(self, chunks: list[dict], index: dict, corpus_freeze: dict, encoder: Encoder,
                 minimum_score: float = 0.5):
        self._vectors = validate_embedding_index(index, chunks, corpus_freeze, encoder)
        self._chunks = {c["chunk_id"]: c for c in chunks}
        self._encoder = encoder
        self._minimum = threshold(minimum_score, -1, 1)

    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> list[dict]:
        filters = validate_query(question, top_k, filters)
        if not question.strip():
            return []
        vectors = self._encoder.encode([question])
        if len(vectors) != 1:
            raise ManualGraphError("query encoder returned an unexpected vector count")
        query = normalized(vectors[0], self._encoder.dimension)
        scores = [(sum(a * b for a, b in zip(query, vector)), cid)
                  for cid, vector in self._vectors.items() if accepts(self._chunks[cid], filters)]
        return [cited_hit(self._chunks[cid], score, "vector", {"model_digest": self._encoder.digest})
                for score, cid in sorted(scores, key=lambda x: (-x[0], x[1]))
                if score >= self._minimum][:top_k]


class HybridRetriever:
    def __init__(self, keyword: Retriever, vector: Retriever, rrf_k: int = 60, candidates: int = 20):
        if not isinstance(rrf_k, int) or not 1 <= rrf_k <= 1000 or not isinstance(candidates, int) or not 5 <= candidates <= 100:
            raise ManualGraphError("invalid hybrid fusion bounds")
        self._keyword, self._vector = keyword, vector
        self._rrf_k, self._candidates = rrf_k, candidates

    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> list[dict]:
        validate_query(question, top_k, filters)
        scores, hits, ranks = {}, {}, {}
        for name, retriever in (("keyword", self._keyword), ("vector", self._vector)):
            for rank, hit in enumerate(retriever.search(question, self._candidates, filters), 1):
                cid = hit["chunk_id"]
                hits[cid] = hit
                scores[cid] = scores.get(cid, 0.0) + 1 / (self._rrf_k + rank)
                ranks.setdefault(cid, {})[name] = rank
        return [{**hits[cid], "score": round(scores[cid], 8), "strategy": "hybrid",
                 "provenance": {"method": "rrf", "rrf_k": self._rrf_k, "ranks": ranks[cid]}}
                for cid in sorted(scores, key=lambda c: (-scores[c], c))[:top_k]]
