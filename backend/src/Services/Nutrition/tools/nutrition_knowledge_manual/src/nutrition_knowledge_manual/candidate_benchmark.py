"""Local technical measurements of explicitly owner-authorized candidate graphs."""
from __future__ import annotations

from .corpus_freeze import validate_retrieval_corpus_binding
from .errors import ManualGraphError
from .graph_retriever import GraphRetriever
from .jsonio import file_sha256, load_json
from .retrieval_artifacts import verify
from .retrieval_graph import validate_candidate
from .retrieval_suite import create_suite
from .source_edition_guard import SourceEditionGuard

CANDIDATE_MODE = "technical_graph_candidate_benchmark"
CANDIDATE_REVIEW_STATUS = "candidate_not_independently_reviewed"


def validate_candidate_authorization(*, authorization, candidate_path, chunks_path, corpus_freeze):
    verify(authorization, "owner_authorized_graph_demo")
    if (authorization.get("owner_accepted") is not True
            or authorization.get("authorized_environment") != "Development"
            or authorization.get("authorized_use") != "academic_demo"
            or authorization.get("production_release_authorized") is not False
            or authorization.get("independent_clinical_review") is not False
            or authorization.get("graph_review_status") != CANDIDATE_REVIEW_STATUS
            or not isinstance(authorization.get("authorization_id"), str)
            or not authorization["authorization_id"].strip()
            or not isinstance(authorization.get("authorization_basis"), str)
            or not authorization["authorization_basis"].strip()):
        raise ManualGraphError("candidate benchmark requires valid owner demo authorization")
    validate_retrieval_corpus_binding(corpus_freeze=corpus_freeze, chunks_path=chunks_path)
    if (authorization.get("corpus_freeze_sha256") != corpus_freeze["content_sha256"]
            or authorization.get("corpus_sha256") != file_sha256(chunks_path)
            or authorization.get("graph_sha256") != file_sha256(candidate_path)):
        raise ManualGraphError("candidate authorization graph/corpus/freeze hash mismatch")
    candidate = load_json(candidate_path)
    validate_candidate(candidate, corpus_freeze)
    if authorization["graph_sha256"] != file_sha256(candidate_path):
        raise ManualGraphError("candidate changed during authorization check")
    return candidate


def create_candidate_suite(*, chunks_path, corpus_freeze, config, encoder, index,
                           candidate_path, authorization):
    # Verify before constructing any retriever; never fabricate review decisions.
    candidate = validate_candidate_authorization(authorization=authorization,
        candidate_path=candidate_path, chunks_path=chunks_path, corpus_freeze=corpus_freeze)
    chunks, retrievers, bindings = create_suite(chunks_path=chunks_path,
        corpus_freeze=corpus_freeze, config=config, encoder=encoder, index=index)
    if "hybrid" not in retrievers:
        raise ManualGraphError("candidate benchmark requires a local embedding index and hybrid seeds")
    graph = GraphRetriever.from_authorized_candidate(seed=retrievers["hybrid"], chunks=chunks,
        corpus_freeze=corpus_freeze, candidate_path=candidate_path, chunks_path=chunks_path,
        authorization=authorization, hops=config["graph_hops"], max_nodes=config["graph_max_nodes"],
        max_edges=config["graph_max_edges"], rrf_k=config["rrf_k"],
        support_weight=config.get("graph_support_weight", 1.0), hop_decay=config.get("graph_hop_decay", .8))
    retrievers["graph-candidate"] = SourceEditionGuard(graph, corpus_freeze["source_revision_id"])
    bindings.update(candidate_demo_authorization_sha256=authorization["content_sha256"],
                    graph_candidate_sha256=candidate["content_sha256"],
                    graph_candidate_file_sha256=authorization["graph_sha256"])
    return chunks, retrievers, bindings
