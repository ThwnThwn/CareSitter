"""Keep edition-specific questions within the single frozen source revision."""
from __future__ import annotations

import re
import unicodedata

from .retrievers import Retriever, validate_query


_YEAR = re.compile(r"\b(?:19|20)\d{2}\b")
_REVISION_YEAR = re.compile(r"(?:^|[-_])((?:19|20)\d{2})$")
_EDITION_TERMS = re.compile(
    r"\b(?:ban cap nhat|ban sua doi|phien ban|an ban|tai ban|edition|revision|"
    r"updated edition|revised edition|latest edition|current edition)\b"
)


def _fold(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value.replace("đ", "d").replace("Đ", "D"))
    return "".join(char for char in decomposed if unicodedata.category(char) != "Mn").casefold()


class SourceEditionGuard:
    """Abstain when an edition request cannot be supported by the frozen source.

    This only guards explicit edition/revision questions. It cannot establish
    clinical answerability or whether an ordinary cited passage supports a claim.
    """

    def __init__(self, retriever: Retriever, source_revision_id: str):
        self._retriever = retriever
        source_id = source_revision_id.split("@", 1)[0]
        match = _REVISION_YEAR.search(source_id)
        self._source_year = int(match.group(1)) if match else None

    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> list[dict]:
        validate_query(question, top_k, filters)
        folded = _fold(question)
        if _EDITION_TERMS.search(folded):
            years = [int(value) for value in _YEAR.findall(folded)]
            if self._source_year is None or not years or any(year != self._source_year for year in years):
                return []
        return self._retriever.search(question, top_k, filters)
