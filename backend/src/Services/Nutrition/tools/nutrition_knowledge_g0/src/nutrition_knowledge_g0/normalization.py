from __future__ import annotations

from dataclasses import dataclass
import unicodedata


@dataclass(frozen=True)
class NormalizedText:
    text: str
    original_starts: tuple[int, ...]
    original_ends: tuple[int, ...]

    def original_range(self, start: int, end: int) -> tuple[int, int]:
        if start < 0 or end <= start or end > len(self.text):
            raise ValueError("Normalized range is outside the text")
        return self.original_starts[start], self.original_ends[end - 1]


def normalize_with_offsets(value: str) -> NormalizedText:
    """Normalize Vietnamese Unicode/whitespace while preserving raw offsets."""

    output: list[str] = []
    starts: list[int] = []
    ends: list[int] = []
    index = 0
    while index < len(value):
        cluster_start = index
        index += 1
        while index < len(value) and unicodedata.combining(value[index]):
            index += 1
        cluster = unicodedata.normalize("NFC", value[cluster_start:index])
        for character in cluster:
            if character.isspace():
                if output and output[-1] != " ":
                    output.append(" ")
                    starts.append(cluster_start)
                    ends.append(index)
                elif output:
                    ends[-1] = index
                continue
            output.append(character)
            starts.append(cluster_start)
            ends.append(index)

    if output and output[-1] == " ":
        output.pop()
        starts.pop()
        ends.pop()

    leading = 0
    while leading < len(output) and output[leading] == " ":
        leading += 1
    return NormalizedText(
        "".join(output[leading:]),
        tuple(starts[leading:]),
        tuple(ends[leading:]),
    )


def normalize_key(value: str) -> str:
    return normalize_with_offsets(value).text.casefold()


def locate_unique(raw_span: str, evidence_quote: str) -> tuple[int, int] | None:
    normalized_span = normalize_with_offsets(raw_span)
    normalized_quote = normalize_with_offsets(evidence_quote).text
    if not normalized_quote:
        return None
    first = normalized_span.text.find(normalized_quote)
    if first < 0 or normalized_span.text.find(normalized_quote, first + 1) >= 0:
        return None
    raw_start, raw_end = normalized_span.original_range(first, first + len(normalized_quote))
    if normalize_with_offsets(raw_span[raw_start:raw_end]).text != normalized_quote:
        return None
    return raw_start, raw_end
