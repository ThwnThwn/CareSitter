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

from nutrition_knowledge_manual.corpus_freeze import freeze_retrieval_corpus
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import content_sha256, file_sha256
from nutrition_knowledge_manual.retrieval_eval import run_retrieval_eval
from nutrition_knowledge_manual.retrieval_review import (
    build_retrieval_review_packet,
    empty_retrieval_review,
    record_retrieval_case_review,
    retrieval_review_status,
    validate_retrieval_review_ledger,
)


class RetrievalReviewTests(unittest.TestCase):
    def test_ledger_is_stale_when_a_question_or_corpus_freeze_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases = fixture.cases()
            freeze = fixture.freeze()
            ledger = empty_retrieval_review(cases=cases, corpus_freeze=freeze)
            ledger = record_retrieval_case_review(
                cases=cases,
                corpus_freeze=freeze,
                ledger=ledger,
                case_id="case-development",
                decision="approved",
                reviewer_id="steward-1",
                reviewer_role="data_steward",
                comment="Locator and source revision were checked.",
            )

            changed_cases = copy.deepcopy(cases)
            changed_cases["cases"][0]["question"] = "Câu hỏi đã thay đổi"
            with self.assertRaisesRegex(ManualGraphError, "different evaluation set"):
                validate_retrieval_review_ledger(
                    cases=changed_cases, corpus_freeze=freeze, ledger=ledger
                )

            changed_freeze = copy.deepcopy(freeze)
            changed_freeze["source_id"] = "other-freeze"
            _sign(changed_freeze, excluding={"created_at_utc", "content_sha256"})
            with self.assertRaisesRegex(ManualGraphError, "different corpus freeze"):
                validate_retrieval_review_ledger(
                    cases=cases, corpus_freeze=changed_freeze, ledger=ledger
                )

    def test_data_steward_cannot_supply_a_clinical_relevance_approval(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()
            ledger = empty_retrieval_review(cases=cases, corpus_freeze=freeze)
            entry = ledger["decisions"][0]
            entry["clinical_relevance_review"] = {
                "decision": "approved",
                "reviewer_id": "steward-1",
                "reviewer_role": "data_steward",
                "comment": "This must not be accepted as a clinical decision.",
                "reviewed_at_utc": "2026-10-22T00:00:00+00:00",
            }
            _sign(ledger)

            with self.assertRaisesRegex(ManualGraphError, "invalid reviewer role"):
                validate_retrieval_review_ledger(
                    cases=cases, corpus_freeze=freeze, ledger=ledger
                )

    def test_packet_only_contains_known_frozen_eligible_chunks(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()

            packet = build_retrieval_review_packet(
                cases=cases,
                corpus_freeze=freeze,
                chunks_path=fixture.chunks_path,
                preview_characters=120,
            )

            citation = packet["cases"][0]["candidate_citations"][0]
            self.assertEqual("eligible-a", citation["chunk_id"])
            self.assertTrue(citation["text_preview_truncated"])
            self.assertNotIn("manual-c", json.dumps(packet, ensure_ascii=False))

            unknown = copy.deepcopy(cases)
            unknown["cases"][0]["relevant_chunk_ids"] = ["manual-c"]
            with self.assertRaisesRegex(ManualGraphError, "unknown or ineligible"):
                build_retrieval_review_packet(
                    cases=unknown,
                    corpus_freeze=freeze,
                    chunks_path=fixture.chunks_path,
                )

    def test_visible_pilot_cannot_pass_release_even_if_case_fields_claim_reviews(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture = _Fixture(Path(folder))
            cases, freeze = fixture.cases(), fixture.freeze()
            for item in cases["cases"]:
                item["review_status"] = "reviewed"
                item["review"] = {
                    "reviewer_id": "dietitian-fixture",
                    "reviewer_role": "dietitian",
                    "comment": "Synthetic test only; this is still a visible pilot.",
                }

            report = run_retrieval_eval(
                cases=cases,
                chunks_path=fixture.chunks_path,
                corpus_freeze=freeze,
                top_k=5,
                minimum_cases=2,
            )

            self.assertFalse(report["validation"]["gold_ready"])
            self.assertFalse(report["release_ready"])
            self.assertIn("cases.require_independent_clinical_review", report["gate_failures"])

            ledger = empty_retrieval_review(cases=cases, corpus_freeze=freeze)
            status = retrieval_review_status(cases=cases, corpus_freeze=freeze, ledger=ledger)
            self.assertFalse(status["release_ready"])


class _Fixture:
    source_id = "fixture-book"
    revision_id = "fixture-book@sha256:fixture"

    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace
        self.workspace.mkdir(parents=True, exist_ok=True)
        self.source_path = self.workspace / "book" / "fixture.pdf"
        self.source_path.parent.mkdir()
        self.source_path.write_bytes(b"fixture source")
        self.manifest_path = self.workspace / "source-manifest.json"
        self.manifest_path.write_text(json.dumps({"schema_version": 1, "sources": [{
            "source_id": self.source_id,
            "revision_id": self.revision_id,
            "path": "book/fixture.pdf",
            "sha256": file_sha256(self.source_path),
            "byte_size": self.source_path.stat().st_size,
            "rights_status": "permitted",
            "allowed_uses": ["local_index", "local_query", "internal_citation"],
        }]}), encoding="utf-8")
        self.chunks_path = self.workspace / "chunks.jsonl"
        chunks = [
            self._chunk("eligible-a", "Nội dung phù hợp A. " * 20, True, "ready_for_retrieval_eval"),
            self._chunk("eligible-b", "Nội dung phù hợp B. " * 20, True, "ready_for_retrieval_eval"),
            self._chunk("manual-c", "Bảng cần duyệt thủ công.", False, "manual_review_required"),
        ]
        self.chunks_path.write_text(
            "".join(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n" for item in chunks),
            encoding="utf-8",
        )
        self.report_path = self.workspace / "chunk-report.json"
        report = {
            "schema_version": 1,
            "source_id": self.source_id,
            "source_revision_id": self.revision_id,
            "source_sha256": file_sha256(self.source_path),
            "rights_status": "permitted",
            "output_sha256": file_sha256(self.chunks_path),
            "chunk_count": 3,
            "index_eligible_count": 2,
            "review_status_counts": {"manual_review_required": 1, "ready_for_retrieval_eval": 2},
            "tokenizer": "fixture",
            "target_tokens": 100,
            "maximum_tokens": 180,
            "overlap_tokens": 10,
        }
        report["content_sha256"] = content_sha256(report)
        self.report_path.write_text(json.dumps(report), encoding="utf-8")

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
            "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "token_count": 10,
            "index_eligible": eligible,
            "review_status": status,
        }

    def freeze(self) -> dict:
        return freeze_retrieval_corpus(
            workspace=self.workspace,
            manifest_path=self.manifest_path,
            source_id=self.source_id,
            chunks_path=self.chunks_path,
            report_path=self.report_path,
        )

    def cases(self) -> dict:
        freeze = self.freeze()
        return {
            "schema_version": 1,
            "status": "pilot_visible",
            "holdout_status": "not_created",
            "corpus": {
                "source_revision_id": self.revision_id,
                "chunks_sha256": file_sha256(self.chunks_path),
                "corpus_freeze_sha256": freeze["content_sha256"],
            },
            "cases": [
                {
                    "case_id": "case-development",
                    "question": "Nội dung phù hợp A ở đâu?",
                    "split": "development",
                    "answerability": "answerable",
                    "relevant_chunk_ids": ["eligible-a"],
                    "review_status": "candidate",
                },
                {
                    "case_id": "case-validation",
                    "question": "Nội dung phù hợp B ở đâu?",
                    "split": "validation",
                    "answerability": "answerable",
                    "relevant_chunk_ids": ["eligible-b"],
                    "review_status": "candidate",
                },
            ],
        }


def _sign(value: dict, excluding: set[str] | None = None) -> None:
    excluded = excluding or {"content_sha256"}
    value["content_sha256"] = content_sha256({
        key: item for key, item in value.items() if key not in excluded
    })


if __name__ == "__main__":
    unittest.main()
