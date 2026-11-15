from __future__ import annotations

from collections import Counter
import math
import re
import unicodedata
from typing import Any

_TOKEN_PATTERN = re.compile(r"[a-z0-9_]+")


class _LexicalIndex:
    def __init__(self, chunks: list[dict[str, Any]]) -> None:
        self._documents = []
        document_frequencies: Counter[str] = Counter()
        for chunk in chunks:
            headings = " ".join(str(value) for value in chunk.get("headings") or [])
            body_tokens = _tokens(str(chunk["text"]))
            heading_tokens = _tokens(headings)
            body_counts = Counter(body_tokens)
            heading_counts = Counter(heading_tokens)
            document_frequencies.update(set(body_counts) | set(heading_counts))
            self._documents.append((chunk, body_counts, heading_counts, len(body_tokens), len(heading_tokens)))
        self._average_body_length = sum(item[3] for item in self._documents) / len(self._documents)
        self._average_heading_length = max(1.0, sum(item[4] for item in self._documents) / len(self._documents))
        count = len(self._documents)
        self._idf = {
            token: math.log(1 + (count - frequency + 0.5) / (frequency + 0.5))
            for token, frequency in document_frequencies.items()
        }

    def search(self, question: str, *, top_k: int) -> list[dict[str, Any]]:
        query_tokens = set(_tokens(question))
        scored = []
        for chunk, body_counts, heading_counts, body_length, heading_length in self._documents:
            score = 0.0
            for token in query_tokens:
                inverse_frequency = self._idf.get(token, 0.0)
                score += _bm25_term(
                    frequency=body_counts.get(token, 0), length=body_length,
                    average_length=self._average_body_length, inverse_frequency=inverse_frequency,
                )
                score += 2.5 * _bm25_term(
                    frequency=heading_counts.get(token, 0), length=heading_length,
                    average_length=self._average_heading_length, inverse_frequency=inverse_frequency,
                )
            if score > 0:
                scored.append((score, chunk))
        scored.sort(key=lambda item: (-item[0], item[1]["chunk_id"]))
        return [
            {
                "chunk_id": chunk["chunk_id"],
                "score": round(score, 6),
                "source_revision_id": chunk["source_revision_id"],
                "source_locator": chunk.get("source_locator"),
                "pdf_page": chunk.get("pdf_page"),
                "printed_page": chunk.get("printed_page"),
            }
            for score, chunk in scored[:top_k]
        ]


def _bm25_term(*, frequency: int, length: int, average_length: float, inverse_frequency: float) -> float:
    if frequency == 0:
        return 0.0
    denominator = frequency + 1.2 * (0.25 + 0.75 * length / average_length)
    return inverse_frequency * frequency * 2.2 / denominator


def _tokens(value: str) -> list[str]:
    decomposed = unicodedata.normalize("NFD", value.replace("đ", "d").replace("Đ", "D").lower())
    without_marks = "".join(character for character in decomposed if unicodedata.category(character) != "Mn")
    return _TOKEN_PATTERN.findall(without_marks)
