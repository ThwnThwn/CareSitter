"""Every approval in this test is synthetic and confined to temporary fixtures."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from generate_runtime_fixtures import generate
from nutrition_knowledge_manual.cli import parser
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.jsonio import serialized_json_bytes
from nutrition_knowledge_manual.retrieval_artifacts import sign
from nutrition_knowledge_manual.runtime_authorization import (create_runtime_authorization,
    verify_runtime_authorization, dispatch_runtime_command)


class RuntimeAuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.workspace = Path(self.temporary.name)
        self.root = self.workspace / "backend/artifacts/nutrition-knowledge-local/synthetic"
        generate(self.root)
        self.manifest_bytes = (self.root / "manifest-keyword.json").read_bytes()
        self.authorization = json.loads((self.root / "authorization-keyword.json").read_bytes())

    def test_valid_authorization_and_verify_cli(self):
        verify_runtime_authorization(self.authorization, self.manifest_bytes, environment="Staging")
        args = parser().parse_args(["--workspace", str(self.workspace), "verify-runtime-authorization",
            "--release-manifest", str(self.root / "manifest-keyword.json"), "--environment", "Staging",
            "--authorization", str(self.root / "authorization-keyword.json")])
        self.assertTrue(dispatch_runtime_command(args, self.workspace)[0])

    def test_signer_and_bindings_are_mandatory(self):
        for key, value in [("reviewer_id", " "), ("role", "developer"), ("comment", ""),
                           ("timestamp", "2026-11-10"), ("timestamp", "2026-11-10T00:00:00+07:00"),
                           ("manifest_sha256", "a" * 64), ("environment", "Production"),
                           ("selected_strategy", "graph")]:
            with self.subTest(key=key, value=value), self.assertRaises(ManualGraphError):
                verify_runtime_authorization(sign({**self.authorization, key: value}),
                                             self.manifest_bytes, environment="Staging")
        with self.assertRaises(ManualGraphError):
            verify_runtime_authorization(self.authorization, self.manifest_bytes, environment="Development")

    def test_no_go_tampered_or_missing_holdout_cannot_be_authorized(self):
        manifest = json.loads(self.manifest_bytes)
        for key, value in [("release_ready", False), ("gate_failures", ["pending"]),
                           ("selected_strategy", None), ("holdout_report_sha256", None),
                           ("strategy_gate_failures", {"keyword": ["failed"]})]:
            with self.subTest(key=key), self.assertRaises(ManualGraphError):
                create_runtime_authorization(serialized_json_bytes(sign({**manifest, key: value})),
                    environment="Staging", reviewer_id="synthetic", role="data_steward", comment="Synthetic only")
        tampered = copy.deepcopy(self.authorization)
        tampered["comment"] = "tampered"
        with self.assertRaises(ManualGraphError):
            verify_runtime_authorization(tampered, self.manifest_bytes, environment="Staging")
        with self.assertRaises(ManualGraphError):
            verify_runtime_authorization(self.authorization, self.manifest_bytes + b"\n", environment="Staging")

    def test_create_cli_requires_explicit_signer_and_does_not_overwrite(self):
        args = parser().parse_args(["--workspace", str(self.workspace), "create-runtime-authorization",
            "--release-manifest", str(self.root / "manifest-keyword.json"), "--environment", "Staging",
            "--output", str(self.root / "synthetic-cli.json"), "--reviewer-id", "synthetic-test",
            "--role", "data_steward", "--comment", "Synthetic fixture only"])
        self.assertTrue(dispatch_runtime_command(args, self.workspace)[0])
        with self.assertRaises(ManualGraphError):
            dispatch_runtime_command(args, self.workspace)
        args.output = self.workspace / "outside.json"
        with self.assertRaises(ManualGraphError):
            dispatch_runtime_command(args, self.workspace)
