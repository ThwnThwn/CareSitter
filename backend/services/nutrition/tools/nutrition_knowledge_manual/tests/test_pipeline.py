from __future__ import annotations

from contextlib import closing
import csv
import io
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[4]
sys.path.insert(0, str(ROOT / "src"))

from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.chunk_pdf import chunk_page
from nutrition_knowledge_manual.chunk_html import extract_html_blocks
from nutrition_knowledge_manual.graph import build_candidate_graph
from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256, load_json
from nutrition_knowledge_manual.seed_chunks import seed_local_chunks
from nutrition_knowledge_manual.seed_postgres import build_seed_sql
from nutrition_knowledge_manual.review import append_decision, empty_decision_ledger, materialize_reviewed_graph
from nutrition_knowledge_manual.release import prepare_release
from nutrition_knowledge_manual.rights import resolve_source


class ManualGraphPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle_path = ROOT / "fixtures" / "catalog.synthetic.json"
        cls.bundle = load_json(cls.bundle_path)
        cls.source = {
            "source_id": "fixture", "revision_id": "fixture@1", "title": "fixture",
            "rights_status": "synthetic", "sha256": file_sha256(cls.bundle_path)
        }
        cls.policy = load_json(ROOT / "config" / "reviewer-policy.json")

    def graph(self):
        return build_candidate_graph(self.bundle, self.source)

    def test_build_is_deterministic_except_timestamp(self):
        first, second = self.graph(), self.graph()
        self.assertEqual(first["content_sha256"], second["content_sha256"])
        self.assertEqual(first["candidates"], second["candidates"])
        self.assertEqual(0, first["automatic_admissions"])

    def test_pdf_chunks_are_page_bound_deterministic_and_normalized(self):
        source = {
            "source_id": "book", "revision_id": "book@1", "sha256": "a" * 64
        }
        paragraph = "Đây là nội dung dinh dưỡng có nguồn. " * 80
        layout = f"DINH DƯỠNG LÂM SÀNG 19\n\n1.1. Khái niệm\n\n{paragraph}\n\n19"
        first, printed_page = chunk_page(
            source=source, pdf_page=20, layout_text=layout,
            target_tokens=120, maximum_tokens=180, overlap_tokens=20
        )
        second, _ = chunk_page(
            source=source, pdf_page=20, layout_text=layout,
            target_tokens=120, maximum_tokens=180, overlap_tokens=20
        )
        self.assertEqual("19", printed_page)
        self.assertEqual([item["chunk_id"] for item in first], [item["chunk_id"] for item in second])
        self.assertTrue(all(item["pdf_page"] == 20 for item in first))
        self.assertTrue(all(item["token_count"] <= 180 for item in first))
        self.assertTrue(all(unicodedata.is_normalized("NFC", item["text"]) for item in first))

    def test_local_chunk_seed_is_idempotent_and_keeps_review_gate(self):
        source = {"source_id": "book", "revision_id": "book@1", "sha256": "a" * 64}
        chunks, _ = chunk_page(
            source=source, pdf_page=8,
            layout_text="1. Mục\n\n" + "Nội dung tổng hợp có trang. " * 45,
            target_tokens=120, maximum_tokens=180, overlap_tokens=20,
        )
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            chunks_path = root / "chunks.jsonl"
            chunks_path.write_text(
                "".join(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n" for item in chunks),
                encoding="utf-8",
            )
            report = {
                "source_id": source["source_id"],
                "source_revision_id": source["revision_id"],
                "source_sha256": source["sha256"],
                "output_sha256": file_sha256(chunks_path),
                "chunk_count": len(chunks),
                "index_eligible_count": sum(item["index_eligible"] for item in chunks),
                "pdf_page_count": 8,
                "maximum_tokens": 180,
            }
            report["content_sha256"] = content_sha256(report)
            report_path = root / "report.json"
            report_path.write_text(json.dumps(report), encoding="utf-8")
            database_path = root / "index.sqlite3"

            first = seed_local_chunks(
                source=source, chunks_path=chunks_path,
                report_path=report_path, database_path=database_path,
            )
            second = seed_local_chunks(
                source=source, chunks_path=chunks_path,
                report_path=report_path, database_path=database_path,
            )
            self.assertEqual("seeded", first["status"])
            self.assertEqual("already_seeded", second["status"])
            with closing(sqlite3.connect(database_path)) as connection:
                self.assertEqual(len(chunks), connection.execute("SELECT COUNT(*) FROM chunks").fetchone()[0])
                self.assertEqual(
                    sum(item["index_eligible"] for item in chunks),
                    connection.execute("SELECT COUNT(*) FROM chunks WHERE index_eligible = 1").fetchone()[0],
                )

            chunks_path.write_text(chunks_path.read_text(encoding="utf-8") + "{}\n", encoding="utf-8")
            with self.assertRaisesRegex(ManualGraphError, "chunk file hash"):
                seed_local_chunks(
                    source=source, chunks_path=chunks_path,
                    report_path=report_path, database_path=database_path,
                )

    def test_postgres_seed_sql_escapes_source_and_preserves_chunk_json(self):
        source = {
            "source_id": "book", "revision_id": "book@1", "title": "O'Reilly",
            "sha256": "a" * 64, "rights_status": "permitted",
        }
        chunks, _ = chunk_page(
            source=source, pdf_page=3,
            layout_text='1. Mục\n\nNội dung có dấu "nháy" và \\gạch chéo. ' * 20,
            target_tokens=120, maximum_tokens=180, overlap_tokens=20,
        )
        script = build_seed_sql(source=source, chunks=chunks, chunks_sha256="b" * 64)
        self.assertIn("'O''Reilly'", script)
        copy_data = script.split("COPY knowledge_import(payload) FROM STDIN WITH (FORMAT csv);\n", 1)[1]
        copy_data = copy_data.split("\\.\n", 1)[0]
        decoded = list(csv.reader(io.StringIO(copy_data)))
        self.assertEqual(chunks, [json.loads(row[0]) for row in decoded])

    def test_html_extraction_keeps_content_and_drops_navigation_and_scripts(self):
        blocks = extract_html_blocks("""
            <html><head><title>Sách dinh dưỡng</title><script>secret()</script></head>
            <body><header>Menu đầu trang</header><nav>Điều hướng</nav>
            <div class="site-menu"><p>Menu không dùng thẻ nav</p></div>
            <main><h1>Chương một</h1><p>Nội dung <strong>hợp lệ</strong>.</p>
            <table><tr><th>Thực phẩm</th><th>Natri</th></tr></table></main>
            <footer>Chân trang</footer></body></html>
        """)
        text = "\n".join(item["text"] for item in blocks)
        self.assertIn("Sách dinh dưỡng", text)
        self.assertIn("Nội dung hợp lệ.", text)
        self.assertIn("Thực phẩm | Natri", text)
        self.assertNotIn("secret", text)
        self.assertNotIn("Điều hướng", text)
        self.assertNotIn("Menu không dùng thẻ nav", text)
        self.assertEqual(list(range(1, len(blocks) + 1)), [item["html_block_ordinal"] for item in blocks])

    def test_html_extraction_prefers_known_article_content_classes(self):
        blocks = extract_html_blocks("""
            <html><head><title>Khuyến nghị</title></head><body>
            <div class="menu"><p>Trang chủ</p><p>Tin tức</p></div>
            <div class="news-description"><p>Mô tả chính thức.</p></div>
            <div class="news-details"><p>Khuyến nghị số 1.</p></div>
            <div class="news-related"><p>Bài viết liên quan.</p></div>
            </body></html>
        """)
        text = "\n".join(item["text"] for item in blocks)
        self.assertIn("Khuyến nghị", text)
        self.assertIn("Mô tả chính thức.", text)
        self.assertIn("Khuyến nghị số 1.", text)
        self.assertNotIn("Trang chủ", text)
        self.assertNotIn("Bài viết liên quan.", text)

    def test_unverified_source_is_rejected(self):
        manifest = load_json(ROOT / "config" / "source-manifest.json")
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ManualGraphError, "metadata-only"):
                resolve_source(workspace=WORKSPACE, manifest_path=path, source_id="moh-hypertension-guide-2010")

    def test_empty_review_materializes_no_records(self):
        graph = self.graph()
        result = materialize_reviewed_graph(graph, empty_decision_ledger(graph), self.policy)
        self.assertEqual(0, result["record_count"])
        self.assertEqual(graph["candidate_count"], result["pending_count"])

    def test_data_steward_cannot_approve_clinical_candidate(self):
        graph = self.graph()
        recipe = next(item for item in graph["candidates"] if item["kind"] == "recipe")
        with self.assertRaisesRegex(ManualGraphError, "cannot decide"):
            append_decision(
                graph=graph, ledger=empty_decision_ledger(graph), candidate_id=recipe["candidate_id"],
                decision="approve", reviewer_id="reviewer", reviewer_role="data_steward",
                comment="reviewed", policy=self.policy
            )

    def test_approved_edge_is_blocked_until_both_nodes_are_approved(self):
        graph = self.graph()
        ledger = empty_decision_ledger(graph)
        edge = next(item for item in graph["candidates"] if item["payload"].get("record_type") == "edge")
        ledger = append_decision(
            graph=graph, ledger=ledger, candidate_id=edge["candidate_id"], decision="approve",
            reviewer_id="reviewer", reviewer_role="dietitian", comment="synthetic review", policy=self.policy
        )
        result = materialize_reviewed_graph(graph, ledger, self.policy)
        self.assertEqual([edge["candidate_id"]], result["blocked_edge_candidate_ids"])

    def test_stale_candidate_digest_is_rejected(self):
        graph = self.graph()
        candidate = graph["candidates"][0]
        ledger = empty_decision_ledger(graph)
        ledger = append_decision(
            graph=graph, ledger=ledger, candidate_id=candidate["candidate_id"], decision="reject",
            reviewer_id="reviewer", reviewer_role="dietitian", comment="synthetic review", policy=self.policy
        )
        ledger["decisions"][0]["candidate_sha256"] = "0" * 64
        with self.assertRaisesRegex(ManualGraphError, "stale or tampered"):
            materialize_reviewed_graph(graph, ledger, self.policy)

    def test_tampered_candidate_graph_is_rejected(self):
        graph = self.graph()
        graph["candidates"][0]["payload"]["properties"]["title"] = "changed"
        with self.assertRaisesRegex(ManualGraphError, "content hash is invalid"):
            materialize_reviewed_graph(graph, empty_decision_ledger(graph), self.policy)

    def test_duplicate_decision_is_rejected(self):
        graph = self.graph()
        candidate = graph["candidates"][0]
        ledger = append_decision(
            graph=graph, ledger=empty_decision_ledger(graph), candidate_id=candidate["candidate_id"],
            decision="reject", reviewer_id="reviewer", reviewer_role="dietitian",
            comment="synthetic review", policy=self.policy
        )
        ledger["decisions"].append(dict(ledger["decisions"][0]))
        with self.assertRaisesRegex(ManualGraphError, "repeats candidate"):
            materialize_reviewed_graph(graph, ledger, self.policy)

    def test_prepare_release_requires_permitted_source(self):
        graph = self.graph()
        with self.assertRaisesRegex(ManualGraphError, "metadata-only|permitted"):
            prepare_release(
                workspace=WORKSPACE, manifest_path=ROOT / "config" / "source-manifest.json",
                bundle_source_id="manual-graph-synthetic-catalog",
                evidence_path=ROOT / "fixtures" / "evidence.synthetic.json",
                graph=graph, ledger=empty_decision_ledger(graph), policy=self.policy
            )

    def test_prepare_release_rejects_synthetic_citation_source(self):
        with tempfile.TemporaryDirectory() as folder:
            temporary = Path(folder)
            relative_path = str(self.bundle_path.relative_to(WORKSPACE)).replace("\\", "/")
            common = {
                "title": "fixture", "path": relative_path,
                "sha256": file_sha256(self.bundle_path), "byte_size": self.bundle_path.stat().st_size,
                "allowed_uses": ["local_index", "local_query", "internal_citation"]
            }
            manifest = {
                "schema_version": 1,
                "sources": [
                    {**common, "source_id": "bundle", "revision_id": "bundle@1",
                     "rights_status": "permitted", "citation_ids": []},
                    {**common, "source_id": "citation", "revision_id": "citation@1",
                     "rights_status": "synthetic", "citation_ids": ["SYNTHETIC_SOURCE"]},
                ]
            }
            manifest_path = temporary / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            source, _ = resolve_source(workspace=WORKSPACE, manifest_path=manifest_path, source_id="bundle")
            graph = build_candidate_graph(self.bundle, source)
            ledger = empty_decision_ledger(graph)
            for candidate in graph["candidates"]:
                role = "data_steward" if candidate["kind"] in {"source", "citation", "concept"} else "dietitian"
                ledger = append_decision(
                    graph=graph, ledger=ledger, candidate_id=candidate["candidate_id"], decision="approve",
                    reviewer_id=f"{role}-fixture", reviewer_role=role,
                    comment="Synthetic review only", policy=self.policy
                )

            with self.assertRaisesRegex(ManualGraphError, "every cited source"):
                prepare_release(
                    workspace=WORKSPACE, manifest_path=manifest_path, bundle_source_id="bundle",
                    evidence_path=ROOT / "fixtures" / "evidence.synthetic.json",
                    graph=graph, ledger=ledger, policy=self.policy
                )

    def test_prepare_release_binds_complete_review_and_rights(self):
        with tempfile.TemporaryDirectory() as folder:
            temporary = Path(folder)
            manifest = {
                "schema_version": 1,
                "sources": [{
                    "source_id": "fixture", "revision_id": "fixture@permitted", "title": "fixture",
                    "path": str(self.bundle_path.relative_to(WORKSPACE)).replace("\\", "/"),
                    "sha256": file_sha256(self.bundle_path), "byte_size": self.bundle_path.stat().st_size,
                    "rights_status": "permitted", "citation_ids": ["SYNTHETIC_SOURCE"],
                    "allowed_uses": ["local_index", "local_query", "internal_citation"]
                }]
            }
            manifest_path = temporary / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            source, _ = resolve_source(workspace=WORKSPACE, manifest_path=manifest_path, source_id="fixture")
            graph = build_candidate_graph(self.bundle, source)
            ledger = empty_decision_ledger(graph)
            for candidate in graph["candidates"]:
                role = "data_steward" if candidate["kind"] in {"source", "citation", "concept"} else "dietitian"
                ledger = append_decision(
                    graph=graph, ledger=ledger, candidate_id=candidate["candidate_id"], decision="approve",
                    reviewer_id=f"{role}-fixture", reviewer_role=role,
                    comment="Synthetic review only", policy=self.policy
                )
            evidence, authorization = prepare_release(
                workspace=WORKSPACE, manifest_path=manifest_path, bundle_source_id="fixture",
                evidence_path=ROOT / "fixtures" / "evidence.synthetic.json",
                graph=graph, ledger=ledger, policy=self.policy
            )
            review = evidence["knowledgeReview"]
            self.assertEqual(graph["candidate_count"], review["approvedCount"])
            self.assertEqual(0, review["pendingCount"])
            self.assertEqual("approved", review["decision"])
            self.assertEqual("release_check_required", authorization["status"])


if __name__ == "__main__":
    unittest.main()
