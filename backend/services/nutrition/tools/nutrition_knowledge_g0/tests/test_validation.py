from pathlib import Path
import unittest

from nutrition_knowledge_g0.validation import validate_contract


class ContractTests(unittest.TestCase):
    def test_repository_contract_has_38_cases_and_fail_closed_books(self) -> None:
        module_root = Path(__file__).resolve().parents[1]
        workspace_root = module_root.parents[4]
        report = validate_contract(module_root, workspace_root)
        self.assertEqual(38, report["fixture_count"])
        self.assertEqual(3, report["rights"]["synthetic"])
        self.assertEqual(5, report["rights"]["unverified"])
        self.assertEqual(4, report["splits"]["selection"]["long_count"])
        self.assertEqual(2, report["splits"]["holdout"]["long_count"])


if __name__ == "__main__":
    unittest.main()
