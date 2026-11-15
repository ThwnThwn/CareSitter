import json
from pathlib import Path
import tempfile
import unittest

from nutrition_knowledge_g0.errors import GateError
from nutrition_knowledge_g0.jsonio import sha256_file
from nutrition_knowledge_g0.manifest import assert_use_allowed, validate_manifest


class ManifestTests(unittest.TestCase):
    def test_unverified_source_is_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.txt"
            source.write_text("metadata only", encoding="utf-8")
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({
                "schema_version": 1,
                "sources": [{
                    "source_id": "unknown-book",
                    "revision_id": "rev-1",
                    "title": "Unknown",
                    "path": "source.txt",
                    "sha256": sha256_file(source),
                    "byte_size": source.stat().st_size,
                    "mime": "text/plain",
                    "language": "vi",
                    "rights_status": "unverified",
                    "allowed_uses": ["metadata"],
                    "rights_evidence": "",
                    "checked_by": "test",
                    "checked_at_utc": "2026-10-20T00:00:00Z"
                }]
            }), encoding="utf-8")
            record = validate_manifest(manifest, root)[0]
            with self.assertRaises(GateError):
                assert_use_allowed(record, "local_index")


if __name__ == "__main__":
    unittest.main()
