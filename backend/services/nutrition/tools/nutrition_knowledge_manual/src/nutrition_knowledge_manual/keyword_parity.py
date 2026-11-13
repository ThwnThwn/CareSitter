"""Local cross-language parity. Stdout contains IDs/hashes only, never questions or chunks."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from .jsonio import content_sha256, file_sha256, load_json, write_json
from .retrieval_eval import load_retrieval_chunks
from .retrievers import KeywordRetriever
from .source_edition_guard import SourceEditionGuard


def expectations(chunks: Path, cases: list[dict]) -> list[dict]:
    corpus = load_retrieval_chunks(chunks)
    rows = []
    for case in cases:
        retriever = KeywordRetriever(corpus, case.get("minimum_score", 0))
        if case.get("edition_guard"):
            retriever = SourceEditionGuard(retriever, case["source_revision_id"])
        filters = {"source_revision_id": case["source_revision_id"]} if case.get("filter_revision") else None
        hits = retriever.search(case["question"], case.get("top_k", 5), filters)
        rows.append({"case_id": case["case_id"],
                     "question_sha256": hashlib.sha256(case["question"].encode()).hexdigest(),
                     "chunk_ids": [h["chunk_id"] for h in hits]})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chunks", type=Path, required=True)
    parser.add_argument("--cases", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--runner-dll", type=Path)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--corpus-freeze", type=Path)
    args = parser.parse_args()
    cases = load_json(args.cases)
    if isinstance(cases, dict):
        cases = cases["cases"]
    if args.config:
        minimum = load_json(args.config)["keyword_minimum_score"]
        cases = [{**case, "minimum_score": minimum} for case in cases]
    if args.corpus_freeze:
        from .corpus_freeze import validate_retrieval_corpus_binding
        freeze = load_json(args.corpus_freeze)
        validate_retrieval_corpus_binding(corpus_freeze=freeze, chunks_path=args.chunks)
        cases = [{**case, "edition_guard": True, "source_revision_id": freeze["source_revision_id"]}
                 for case in cases]
    expected = expectations(args.chunks, cases)
    if args.runner_dll:
        # Book text stays in local processes. Capture errors too: do not echo arbitrary child output.
        child = subprocess.run(["dotnet", str(args.runner_dll), str(args.chunks.resolve())],
                               input=json.dumps(cases), text=True, capture_output=True)
        if child.returncode:
            print(json.dumps({"runner_error_sha256": content_sha256(child.stderr)}))
            return 1
        try:
            actual = json.loads(child.stdout)
        except ValueError:
            print(json.dumps({"runner_output_sha256": content_sha256(child.stdout)}))
            return 1
        if actual != expected:
            print(json.dumps({"expected_sha256": content_sha256(expected), "actual_sha256": content_sha256(actual)}))
            return 1
    if args.output:
        write_json(args.output, expected)
    print(json.dumps({"corpus_sha256": file_sha256(args.chunks), "rows": expected}, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        # Exception text may originate from malformed local data; never emit it.
        print(json.dumps({"error_type_sha256": content_sha256(type(error).__name__)}))
        sys.exit(1)
