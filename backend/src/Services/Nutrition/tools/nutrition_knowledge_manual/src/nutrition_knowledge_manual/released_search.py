"""Read-only cited search over a fully released retrieval revision."""
from __future__ import annotations

from .errors import ManualGraphError
from .retrieval_artifacts import verify
from .retrievers import Retriever, validate_query


def require_internal_search_release(manifest: dict) -> None:
    verify(manifest, "retrieval_release_manifest")
    if (manifest.get("release_ready") is not True
            or manifest.get("decision") != "simplest_strategy_passing_all_gates"
            or manifest.get("scope") != "M4_local_retrieval_evidence_only"
            or manifest.get("runtime_integration_authorized") is not False
            or manifest.get("gate_failures") != []
            or manifest.get("selected_strategy") not in {"keyword", "vector", "hybrid", "graph"}):
        raise ManualGraphError("retrieval release is not ready for internal search")


class ReleasedEvidenceSearch:
    """Expose one search interface after the release evidence has been rebuilt."""

    def __init__(self, *, manifest: dict, rebuilt_manifest: dict,
                 chunks: list[dict], retriever: Retriever):
        require_internal_search_release(manifest)
        if manifest != rebuilt_manifest:
            raise ManualGraphError("retrieval release no longer matches its evidence")
        self._strategy = manifest["selected_strategy"]
        self._revision = manifest["bindings"]["corpus_freeze_sha256"]
        self._chunks = {chunk["chunk_id"]: chunk for chunk in chunks}
        self._retriever = retriever

    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> dict:
        filters = validate_query(question, top_k, filters)
        if not question.strip() or top_k > 10:
            raise ManualGraphError("internal search requires a question and at most 10 cited hits")
        hits = []
        raw_hits = self._retriever.search(question, top_k, filters)
        if not isinstance(raw_hits, list) or len(raw_hits) > top_k:
            raise ManualGraphError("retrieval returned too many cited hits")
        for hit in raw_hits:
            if not isinstance(hit, dict):
                raise ManualGraphError("retrieval hit is not a cited record")
            chunk = self._chunks.get(hit.get("chunk_id"))
            if (chunk is None or chunk.get("index_eligible") is not True
                    or chunk.get("review_status") != "ready_for_retrieval_eval"
                    or hit.get("strategy") != self._strategy
                    or any(chunk.get(key) != value for key, value in filters.items())
                    or any(hit.get(key) != chunk.get(key) for key in
                           ("source_revision_id", "source_locator", "pdf_page", "printed_page"))):
                raise ManualGraphError("retrieval hit lacks eligible, matching source evidence")
            excerpt = str(chunk["text"])[:600].rstrip()
            hits.append({key: hit[key] for key in
                         ("chunk_id", "source_revision_id", "source_locator",
                          "pdf_page", "printed_page", "score", "strategy", "provenance")}
                        | {"text_preview": excerpt,
                           "text_preview_truncated": len(excerpt) < len(chunk["text"]),
                           "text_sha256": chunk["text_sha256"]})
        return {"mode": "released_internal_cited_search", "corpus_freeze_sha256": self._revision,
                "strategy": self._strategy, "hits": hits}
