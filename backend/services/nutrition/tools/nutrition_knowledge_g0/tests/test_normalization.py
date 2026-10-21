import unicodedata
import unittest

from nutrition_knowledge_g0.normalization import locate_unique, normalize_with_offsets


class NormalizationTests(unittest.TestCase):
    def test_nfd_and_nbsp_map_back_to_original_offsets(self) -> None:
        raw = unicodedata.normalize("NFD", "Sữa") + "\u00a0chua có protein."
        located = locate_unique(raw, "Sữa chua")
        self.assertIsNotNone(located)
        start, end = located
        self.assertEqual("Sữa chua", normalize_with_offsets(raw[start:end]).text)

    def test_repeated_quote_is_not_locatable(self) -> None:
        self.assertIsNone(locate_unique("natri và natri", "natri"))


if __name__ == "__main__":
    unittest.main()
