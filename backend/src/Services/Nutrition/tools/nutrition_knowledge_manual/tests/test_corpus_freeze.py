from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from nutrition_knowledge_manual.corpus_freeze import (
    freeze_retrieval_corpus,
    validate_retrieval_corpus_freeze,
)
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256


class CorpusFreezeTests(unittest.TestCase):
    def test_freeze_is_deterministic_and_excludes_manual_chunks(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))

            first = fixture.freeze()
            second = fixture.freeze()

            self.assertEqual(first["content_sha256"], second["content_sha256"])
            self.assertEqual(2, first["eligible_chunk_count"])
            self.assertEqual(1, first["excluded_chunk_count"])
            self.assertEqual({"manual_review_required": 1}, first["excluded_by_review_status"])
            self.assertEqual(["eligible-a", "eligible-b"], [
                item["chunk_id"] for item in first["eligible_chunk_identities"]
            ])
            self.assertNotIn("text", first["eligible_chunk_identities"][0])
            self.assertEqual(file_sha256(fixture.manifest_path), first["source_manifest_sha256"])
            self.assertIn("rights.py", first["validation_contract_files_sha256"])

    def test_freeze_rejects_changed_source_manifest_even_when_source_stays_valid(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            freeze = fixture.freeze()
            manifest = json.loads(fixture.manifest_path.read_text(encoding="utf-8"))
            manifest["sources"][0]["title"] = "Metadata changed after freeze"
            fixture.manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            with self.assertRaisesRegex(ManualGraphError, "no longer matches"):
                validate_retrieval_corpus_freeze(
                    corpus_freeze=freeze,
                    workspace=fixture.workspace,
                    manifest_path=fixture.manifest_path,
                    source_id=fixture.source_id,
                    chunks_path=fixture.chunks_path,
                    report_path=fixture.report_path,
                )

    def test_freeze_rejects_changed_chunk_artifact_and_invalid_manual_admission(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            freeze = fixture.freeze()
            modified = copy.deepcopy(fixture.chunks)
            modified[0]["text"] = "Nội dung đã bị thay đổi nhưng vẫn hợp lệ."
            modified[0]["text_sha256"] = _text_hash(modified[0]["text"])
            fixture.write_chunks(modified)

            with self.assertRaisesRegex(ManualGraphError, "chunk file hash does not match"):
                fixture.freeze()
            with self.assertRaisesRegex(ManualGraphError, "chunk file hash does not match"):
                validate_retrieval_corpus_freeze(
                    corpus_freeze=freeze,
                    workspace=fixture.workspace,
                    manifest_path=fixture.manifest_path,
                    source_id=fixture.source_id,
                    chunks_path=fixture.chunks_path,
                    report_path=fixture.report_path,
                )

            fixture = _Fixture(Path(folder) / "manual")
            invalid = copy.deepcopy(fixture.chunks)
            invalid[2]["index_eligible"] = True
            fixture.write_chunks(invalid)
            fixture.write_report(chunks=invalid)
            with self.assertRaisesRegex(ManualGraphError, "bypasses the review gate"):
                fixture.freeze()

    def test_freeze_rejects_source_that_no_longer_matches_manifest_hash(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            fixture.source_path.write_bytes(b"changed source")

            with self.assertRaisesRegex(ManualGraphError, "source hash mismatch"):
                fixture.freeze()

    def test_freeze_rejects_a_different_validator_code_revision(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            freeze = fixture.freeze()
            freeze["validator_code_sha256"] = "0" * 64
            freeze["content_sha256"] = content_sha256({
                key: value for key, value in freeze.items()
                if key not in {"created_at_utc", "content_sha256"}
            })

            with self.assertRaisesRegex(ManualGraphError, "different validator code revision"):
                validate_retrieval_corpus_freeze(
                    corpus_freeze=freeze,
                    workspace=fixture.workspace,
                    manifest_path=fixture.manifest_path,
                    source_id=fixture.source_id,
                    chunks_path=fixture.chunks_path,
                    report_path=fixture.report_path,
                )


class _Fixture:
    source_id = "fixture-book"
    revision_id = "fixture-book@sha256:fixture"

    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace
        self.workspace.mkdir(parents=True, exist_ok=True)
        self.source_path = self.workspace / "book" / "fixture.pdf"
        self.source_path.parent.mkdir()
        self.source_path.write_bytes(b"fixture source")
        source_hash = file_sha256(self.source_path)
        self.manifest_path = self.workspace / "source-manifest.json"
        self.manifest_path.write_text(json.dumps({
            "schema_version": 1,
            "sources": [{
                "source_id": self.source_id,
                "revision_id": self.revision_id,
                "path": "book/fixture.pdf",
                "sha256": source_hash,
                "byte_size": self.source_path.stat().st_size,
                "rights_status": "permitted",
                "allowed_uses": ["local_index", "local_query", "internal_citation"],
            }],
        }), encoding="utf-8")
        self.chunks_path = self.workspace / "chunks.jsonl"
        self.report_path = self.workspace / "chunk-report.json"
        self.chunks = [
            self._chunk("eligible-a", "Nội dung phù hợp A.", True, "ready_for_retrieval_eval"),
            self._chunk("eligible-b", "Nội dung phù hợp B.", True, "ready_for_retrieval_eval"),
            self._chunk("manual-c", "Bảng cần duyệt thủ công.", False, "manual_review_required"),
        ]
        self.write_chunks(self.chunks)
        self.write_report(chunks=self.chunks)

    def _chunk(self, chunk_id: str, text: str, eligible: bool, status: str) -> dict:
        return {
            "chunk_id": chunk_id,
            "source_id": self.source_id,
            "source_revision_id": self.revision_id,
            "source_sha256": file_sha256(self.source_path),
            "source_locator": f"pdf-page:{len(chunk_id)}",
            "pdf_page": len(chunk_id),
            "printed_page": str(len(chunk_id) - 1),
            "headings": ["Dinh dưỡng"],
            "text": text,
            "text_sha256": _text_hash(text),
            "token_count": 10,
            "index_eligible": eligible,
            "review_status": status,
        }

    def write_chunks(self, chunks: list[dict]) -> None:
        self.chunks_path.write_text(
            "".join(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n" for item in chunks),
            encoding="utf-8",
        )

    def write_report(self, *, chunks: list[dict]) -> None:
        status_counts: dict[str, int] = {}
        for chunk in chunks:
            status_counts[chunk["review_status"]] = status_counts.get(chunk["review_status"], 0) + 1
        report = {
            "schema_version": 1,
            "source_id": self.source_id,
            "source_revision_id": self.revision_id,
            "source_sha256": file_sha256(self.source_path),
            "rights_status": "permitted",
            "output_sha256": file_sha256(self.chunks_path),
            "chunk_count": len(chunks),
            "index_eligible_count": sum(item["index_eligible"] for item in chunks),
            "review_status_counts": dict(sorted(status_counts.items())),
            "tokenizer": "fixture",
            "target_tokens": 100,
            "maximum_tokens": 180,
            "overlap_tokens": 10,
        }
        report["content_sha256"] = content_sha256(report)
        self.report_path.write_text(json.dumps(report), encoding="utf-8")

    def freeze(self) -> dict:
        return freeze_retrieval_corpus(
            workspace=self.workspace,
            manifest_path=self.manifest_path,
            source_id=self.source_id,
            chunks_path=self.chunks_path,
            report_path=self.report_path,
        )


def _text_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


if __name__ == "__main__":
    unittest.main()
