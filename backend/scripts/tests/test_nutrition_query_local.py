from contextlib import redirect_stdout
import importlib.util
from io import StringIO
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "nutrition-query-local.py"
SPEC = importlib.util.spec_from_file_location("nutrition_query_local", SCRIPT)
assert SPEC and SPEC.loader
QUERY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(QUERY)


class Utf8StringIO(StringIO):
    def reconfigure(self, **_):
        pass


class NutritionQueryLocalTests(unittest.TestCase):
    def test_meal_suggestion_request_does_not_run_book_retrieval(self):
        output = Utf8StringIO()
        with patch.object(sys, "argv", [str(SCRIPT), "--question",
                                        "Tôi bị dị ứng với tôm đề xuất cho tôi 1 số món đi",
                                        "--strategy", "hybrid"]), \
                patch.object(QUERY, "_load_verified_inputs",
                             side_effect=AssertionError("book retrieval must not run")), \
                redirect_stdout(output):
            result = QUERY.main()
        self.assertEqual(0, result)
        self.assertIn("gợi ý món", output.getvalue())
        self.assertNotIn("PDF trang", output.getvalue())


if __name__ == "__main__":
    unittest.main()
