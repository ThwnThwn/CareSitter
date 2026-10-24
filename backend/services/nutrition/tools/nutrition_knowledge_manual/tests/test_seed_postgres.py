from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[4]
sys.path.insert(0, str(ROOT / "src"))

from nutrition_knowledge_manual.chunk_pdf import chunk_page
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256, write_json
from nutrition_knowledge_manual.seed_postgres import build_seed_sql, seed_postgres_chunks, verify_postgres_chunks


@unittest.skipUnless(os.environ.get("NUTRITION_SEED_TEST_CONTAINER"), "requires a disposable PostgreSQL seed test container")
class PostgresChunkSeedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.container = os.environ["NUTRITION_SEED_TEST_CONTAINER"]
        inspection = subprocess.run(
            ["docker", "inspect", cls.container], capture_output=True, text=True, check=True,
        )
        details = json.loads(inspection.stdout)[0]
        # These tests mutate data only in an explicitly labelled, disposable container.
        if not cls.container.startswith("nutrition-knowledge-seed-test-") or (
            details["Config"]["Labels"].get("caresitter.test") != "nutrition-knowledge-seed"
        ):
            raise RuntimeError("Refusing to run seed tests against a non-test container")
        migration = (WORKSPACE / "backend/init-db/nutrition-service/09-knowledge-chunks.sql").read_text(encoding="utf-8")
        cls.sql("CREATE SCHEMA nutrition;\n" + migration + """
            CREATE ROLE knowledge_seed_reader LOGIN;
            GRANT USAGE ON SCHEMA nutrition TO knowledge_seed_reader;
            GRANT SELECT ON nutrition.knowledge_sources,nutrition.knowledge_chunks TO knowledge_seed_reader;
            ALTER ROLE knowledge_seed_reader SET default_transaction_read_only = on;
        """)

    @classmethod
    def sql(cls, script: str, database: str = "nutrition", check: bool = True):
        result = subprocess.run(
            ["docker", "exec", "-i", "-e", "PGCLIENTENCODING=UTF8", cls.container,
             "psql", "-X", "-w", "-qAt", "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", database],
            input=script, text=True, encoding="utf-8", capture_output=True, timeout=30,
        )
        if check and result.returncode:
            raise AssertionError(result.stderr)
        return result

    def setUp(self):
        self.sql("TRUNCATE nutrition.knowledge_chunks,nutrition.knowledge_sources;")
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.source = {
            "source_id": "synthetic-seed", "revision_id": "synthetic-seed@1",
            "title": "Dinh dưỡng O'Reilly $$; \\.\nTiêu đề \\ phần 2",
            "sha256": "a" * 64, "rights_status": "synthetic",
        }
        self.chunks, _ = chunk_page(
            source=self.source, pdf_page=8,
            layout_text="DINH DƯỠNG LÂM SÀNG 7\n\n1. Mục\n\n" + "Nội dung tổng hợp có nguồn. " * 45 + "\n\n7",
            target_tokens=120, maximum_tokens=180, overlap_tokens=20,
        )
        short, _ = chunk_page(
            source=self.source, pdf_page=9, layout_text="Đoạn ngắn cần kiểm tra.",
            target_tokens=120, maximum_tokens=180, overlap_tokens=20,
        )
        self.chunks.extend(short)
        self.chunks_path = Path(self.folder.name) / "chunks.jsonl"
        self.chunks_path.write_text(
            "".join(json.dumps(chunk, ensure_ascii=False) + "\n" for chunk in self.chunks), encoding="utf-8",
        )
        report = {
            "source_id": self.source["source_id"], "source_revision_id": self.source["revision_id"],
            "source_sha256": self.source["sha256"], "output_sha256": file_sha256(self.chunks_path),
            "chunk_count": len(self.chunks), "index_eligible_count": sum(c["index_eligible"] for c in self.chunks),
            "pdf_page_count": 9, "maximum_tokens": 180,
        }
        report["content_sha256"] = content_sha256(report)
        self.report_path = Path(self.folder.name) / "report.json"
        write_json(self.report_path, report)

    def run_operation(self, operation=seed_postgres_chunks, user="postgres"):
        return operation(
            source=self.source, chunks_path=self.chunks_path, report_path=self.report_path,
            container=self.container, database_user=user,
        )

    def snapshot(self):
        return self.sql("""
            SELECT md5(coalesce(string_agg(to_jsonb(s)::text,'' ORDER BY source_revision_id),''))
            FROM nutrition.knowledge_sources s;
            SELECT md5(coalesce(string_agg(to_jsonb(c)::text,'' ORDER BY chunk_id),''))
            FROM nutrition.knowledge_chunks c;
        """).stdout

    def test_repeated_and_concurrent_seed_preserves_all_data(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(lambda _: self.run_operation(), range(2)))
        self.assertTrue(all(result["chunk_count"] == len(self.chunks) for result in outcomes))
        before = self.snapshot()
        self.run_operation()
        result = self.run_operation(verify_postgres_chunks, "knowledge_seed_reader")
        self.assertEqual("verified_read_only", result["status"])
        self.assertEqual(before, self.snapshot())

    def test_seed_rejects_metadata_drift_and_rolls_back_partial_repair(self):
        for assignment, page in [
            ("printed_page=NULL", 8),
            ("printed_page='999'", 8),
            ("headings='[\"wrong heading\"]'::jsonb", 8),
            ("content_type='table_candidate'", 9),
        ]:
            with self.subTest(assignment=assignment):
                self.sql("TRUNCATE nutrition.knowledge_chunks,nutrition.knowledge_sources;")
                self.run_operation()
                self.sql(f"""
                    UPDATE nutrition.knowledge_chunks SET {assignment} WHERE pdf_page={page};
                    DELETE FROM nutrition.knowledge_chunks WHERE chunk_id=(
                        SELECT chunk_id FROM nutrition.knowledge_chunks WHERE pdf_page<>{page} LIMIT 1
                    );
                """)
                before = self.snapshot()
                with self.assertRaises(ManualGraphError):
                    self.run_operation()
                with self.assertRaises(ManualGraphError):
                    self.run_operation(verify_postgres_chunks, "knowledge_seed_reader")
                self.assertEqual(before, self.snapshot())

    def test_read_only_verification_detects_missing_chunk_without_repair(self):
        self.run_operation()
        self.sql("DELETE FROM nutrition.knowledge_chunks WHERE pdf_page=9;")
        before = self.snapshot()
        with self.assertRaisesRegex(ManualGraphError, "chunks differ"):
            self.run_operation(verify_postgres_chunks, "knowledge_seed_reader")
        self.assertEqual(before, self.snapshot())

    def test_verification_detects_source_metadata_drift(self):
        self.run_operation()
        self.sql("UPDATE nutrition.knowledge_sources SET title='Changed title';")
        before = self.snapshot()
        with self.assertRaisesRegex(ManualGraphError, "source is missing or differs"):
            self.run_operation(verify_postgres_chunks, "knowledge_seed_reader")
        with self.assertRaises(ManualGraphError):
            self.run_operation()
        self.assertEqual(before, self.snapshot())

    def test_seed_rejects_wrong_database_before_writing(self):
        script = build_seed_sql(
            source=self.source, chunks=self.chunks, chunks_sha256=file_sha256(self.chunks_path),
        )
        result = self.sql(script, database="postgres", check=False)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Expected migrated Nutrition knowledge database", result.stderr)
        self.assertEqual("\n", self.sql("SELECT to_regnamespace('nutrition');", database="postgres").stdout)
