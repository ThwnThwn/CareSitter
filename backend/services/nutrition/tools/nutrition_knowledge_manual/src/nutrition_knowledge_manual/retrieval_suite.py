from __future__ import annotations

from pathlib import Path

from .corpus_freeze import validate_retrieval_corpus_binding
from .errors import ManualGraphError
from .graph_retriever import GraphRetriever
from .jsonio import content_sha256
from .retrieval_eval import load_retrieval_chunks
from .retrievers import EmbeddingRetriever, HybridRetriever, KeywordRetriever
from .source_edition_guard import SourceEditionGuard

CONFIG_KEYS = {"schema_version", "keyword_minimum_score", "vector_minimum_score", "rrf_k",
               "fusion_candidates", "graph_hops", "graph_max_nodes", "graph_max_edges"}


def create_suite(*, chunks_path: Path, corpus_freeze: dict, config: dict,
                 encoder=None, index: dict | None = None, candidate: dict | None = None,
                 ledger: dict | None = None, graph: dict | None = None) -> tuple[list[dict], dict, dict]:
    validate_retrieval_corpus_binding(corpus_freeze=corpus_freeze, chunks_path=chunks_path)
    if set(config) != CONFIG_KEYS or config["schema_version"] != 1:
        raise ManualGraphError("retrieval config must use the exact version 1 schema")
    chunks = load_retrieval_chunks(chunks_path)
    keyword = KeywordRetriever(chunks, config["keyword_minimum_score"])
    retrievers = {"keyword": keyword}
    if (index is None) != (encoder is None):
        raise ManualGraphError("embedding index and encoder must be supplied together")
    if index is not None:
        vector = EmbeddingRetriever(chunks, index, corpus_freeze, encoder, config["vector_minimum_score"])
        retrievers["vector"] = vector
        retrievers["hybrid"] = HybridRetriever(keyword, vector, config["rrf_k"], config["fusion_candidates"])
    if any(x is not None for x in (candidate, ledger, graph)):
        if any(x is None for x in (candidate, ledger, graph)) or "hybrid" not in retrievers:
            raise ManualGraphError("graph strategy requires hybrid, candidate, ledger and reviewed graph")
        retrievers["graph"] = GraphRetriever(retrievers["hybrid"], chunks, corpus_freeze,
            candidate, ledger, graph, config["graph_hops"], config["graph_max_nodes"], config["graph_max_edges"])
    retrievers = {name: SourceEditionGuard(retriever, corpus_freeze["source_revision_id"])
                  for name, retriever in retrievers.items()}
    bindings = {"corpus_freeze_sha256": corpus_freeze["content_sha256"],
                "config": config, "config_sha256": content_sha256(config),
                "index_sha256": index["content_sha256"] if index else None,
                "model": index["model"] if index else None,
                "graph_sha256": graph["content_sha256"] if graph else None,
                "graph_review_sha256": ledger["content_sha256"] if ledger else None,
                "graph_candidate_sha256": candidate["content_sha256"] if candidate else None}
    return chunks, retrievers, bindings
