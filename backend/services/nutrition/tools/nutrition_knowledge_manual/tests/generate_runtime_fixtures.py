"""Generate only invented, committable R4 fixtures; never reads a real release or book."""
from pathlib import Path
import json

from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256, serialized_json_bytes, write_json
from nutrition_knowledge_manual.keyword_parity import expectations
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.review_policy import metadata
from nutrition_knowledge_manual.runtime_authorization import create_runtime_authorization

DESTINATION = Path(__file__).resolve().parents[3] / "tests/CareSitter.Nutrition.Tests/Fixtures/ReleasedRetrieval"


def generate(destination: Path = DESTINATION):
    destination.mkdir(parents=True, exist_ok=True)
    chunks = []
    for chunk_id, headings, text in [
        ("synthetic-a", ["ĐẬU xanh", "Cửa hàng giả lập"], "Đậu xanh đậu xanh robot 42 alpha_beta."),
        ("synthetic-b", ["Robot"], "đậu đỏ robot chạy qua cầu số 42."),
        ("synthetic-c", [], "robot chạy chạy chạy."),
        ("synthetic-d", ["Tie"], "identical zeta"),
        ("synthetic-e", ["Tie"], "identical zeta"),
        ("synthetic-f", [], "!!!"),
    ]:
        chunks.append({"chunk_id": chunk_id, "headings": headings, "text": text,
            "source_revision_id": "synthetic-2019@fixture", "source_id": "synthetic-only",
            "index_eligible": True, "review_status": "ready_for_retrieval_eval",
            "source_locator": "synthetic:" + chunk_id, "pdf_page": 1, "printed_page": None})
    chunks.append({**chunks[0], "chunk_id": "synthetic-excluded", "index_eligible": False,
                   "text": "excludedword", "review_status": "pending"})
    corpus = destination / "corpus.jsonl"
    corpus.write_bytes(b"".join((json.dumps(c, ensure_ascii=False) + "\n").encode() for c in chunks))
    cases = [{"case_id": f"synthetic-q{i:02}", "question": question} for i, question in enumerate([
        "ĐẬU xanh", "đậu xanh", "dau xanh", "robot 42", "alpha_beta", "identical", "Tie zeta",
        "", "!!!", "unknownword", "excludedword", "robot robot ROBOT", "cửa hàng", "đậu đỏ", "chạy",
    ])]
    cases += [{"case_id": "synthetic-threshold", "question": "robot", "minimum_score": 10000},
              {"case_id": "synthetic-top1", "question": "identical", "top_k": 1},
              {"case_id": "synthetic-filter", "question": "robot", "source_revision_id": "other", "filter_revision": True}]
    for year in ("2019", "2024", ""):
        cases.append({"case_id": "synthetic-edition-" + (year or "missing"),
                      "question": "robot phiên bản " + year, "edition_guard": True,
                      "source_revision_id": "synthetic-2019@fixture"})
    # Round-before-threshold boundary: same score, one threshold on either side.
    from nutrition_knowledge_manual.keyword_retriever import _LexicalIndex
    score = _LexicalIndex(chunks[:-1]).search("alpha_beta", top_k=1)[0]["score"]
    cases += [{"case_id": "synthetic-round-accept", "question": "alpha_beta", "minimum_score": score},
              {"case_id": "synthetic-round-reject", "question": "alpha_beta", "minimum_score": score + 0.0000001}]
    write_json(destination / "cases.json", cases)
    write_json(destination / "expected.json", expectations(corpus, cases))
    freeze = {"schema_version": 1, "mode": "local_retrieval_corpus_freeze",
              "source_revision_id": "synthetic-2019@fixture", "chunks_sha256": file_sha256(corpus)}
    freeze = sign(freeze)
    write_json(destination / "freeze.json", freeze)
    graph = sign({"schema_version": 1, "mode": "reviewed_retrieval_graph", **metadata(),
                  "corpus_freeze_sha256": freeze["content_sha256"],
                  "nodes": [{"id": "synthetic-topic", "label": "robot"},
                            {"id": "synthetic-node", "label": "synthetic-a", "chunk_id": "synthetic-a"}],
                  "edges": [{"from": "synthetic-topic", "to": "synthetic-node"}]})
    write_json(destination / "graph.json", graph)
    for strategy in ("keyword", "graph", "vector", "hybrid"):
        config = {"schema_version": 1, "keyword_minimum_score": 0.0}
        manifest = sign({"schema_version": 1, "mode": "retrieval_release_manifest", **metadata(),
            "release_ready": True, "runtime_integration_authorized": False, "gate_failures": [],
            "strategy_gate_failures": {strategy: []}, "selected_strategy": strategy,
            "decision": "simplest_strategy_passing_all_gates",
            "benchmark_freeze_sha256": "1" * 64, "holdout_report_sha256": "2" * 64,
            "holdout_review_sha256": "3" * 64,
            "bindings": {"corpus_freeze_sha256": freeze["content_sha256"],
                         "config": config, "config_sha256": content_sha256(config),
                         "graph_sha256": graph["content_sha256"]}})
        manifest_bytes = serialized_json_bytes(manifest)
        (destination / f"manifest-{strategy}.json").write_bytes(manifest_bytes)
        authorization = create_runtime_authorization(manifest_bytes, environment="Staging",
            reviewer_id="synthetic-fixture-only", role="data_steward",
            comment="Dữ liệu tổng hợp; không phải phê duyệt phát hành thật.")
        authorization = sign({**authorization, "timestamp": "2026-11-10T00:00:00+00:00"})
        write_json(destination / f"authorization-{strategy}.json", authorization)


if __name__ == "__main__":
    generate()
