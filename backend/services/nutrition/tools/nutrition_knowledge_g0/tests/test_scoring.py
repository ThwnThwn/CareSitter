import unittest

from nutrition_knowledge_g0.fixtures import FixtureCase, Span
from nutrition_knowledge_g0.scoring import score_run


ONTOLOGY = {
    "entity_types": ["Food", "Nutrient"],
    "relation_types": ["CONTAINS"],
    "claim_types": ["NUTRIENT_AMOUNT"],
    "aliases": {},
}


class ScoringTests(unittest.TestCase):
    def setUp(self) -> None:
        self.case = FixtureCase(
            case_id="one",
            split="selection",
            primary_group="numeric",
            tags=("numeric",),
            text="Cá có protein.",
            spans=(Span("s1", "Cá có protein.", 0, 15),),
            gold={
                "entities": [
                    {"type": "Food", "name": "Cá", "span_id": "s1"},
                    {"type": "Nutrient", "name": "protein", "span_id": "s1"},
                ],
                "relations": [{"type": "CONTAINS", "subject": "Cá", "object": "protein", "span_id": "s1"}],
                "claims": [],
            },
        )

    def test_extraction_is_independent_from_evidence_location(self) -> None:
        prediction = {
            "entities": [
                {"type": "Food", "name": "Cá", "span_id": "s1", "evidence_quote": "không có"},
                {"type": "Nutrient", "name": "protein", "span_id": "s1", "evidence_quote": "không có"},
            ],
            "relations": [
                {"type": "CONTAINS", "subject": "Cá", "object": "protein", "span_id": "s1", "evidence_quote": "không có"}
            ],
            "claims": [],
        }
        score = score_run([self.case], {"one": prediction}, ONTOLOGY)
        self.assertEqual(1.0, score["entity"]["f1"])
        self.assertEqual(1.0, score["relation_claim"]["f1"])
        self.assertEqual(0.0, score["evidence_locatable_rate"])
        self.assertEqual(0.0, score["admission_precision"])

    def test_missing_prediction_is_not_semantically_valid(self) -> None:
        score = score_run([self.case], {}, ONTOLOGY)
        self.assertEqual(0, score["semantic_valid_cases"])


if __name__ == "__main__":
    unittest.main()
