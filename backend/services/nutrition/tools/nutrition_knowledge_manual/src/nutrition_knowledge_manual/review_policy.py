"""Explicit review policy; no environment or artifact can opt a caller in."""
from .errors import ManualGraphError

DEFAULT = "source_and_clinical"
REFERENCE = "non_medical_reference"
POLICIES = (DEFAULT, REFERENCE)
REASON = "no_clinical_reviewer_non_medical_reference"


def metadata(policy=DEFAULT):
    if policy not in POLICIES:
        raise ManualGraphError("unsupported review policy")
    reference = policy == REFERENCE
    return {"review_policy": policy, "clinical_review_performed": not reference,
            "independent_clinical_review": not reference,
            "intended_use": "academic_reference_non_medical" if reference else "reviewed_nutrition_reference",
            "production_public_release": False,
            **({"clinical_review_not_performed_reason": REASON} if reference else {})}


def check(policy, *documents, role=None):
    metadata(policy)
    if policy != REFERENCE:
        return
    if role in {"dietitian", "physician"}:
        raise ManualGraphError("non_medical_reference forbids clinical reviewer roles")
    def visit(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if ((key in {"clinical_review", "clinical_relevance_review", "clinicalReview"}
                     and child is not None)
                        or (key in {"clinical_review_performed", "independent_clinical_review"}
                            and child is not False)
                        or (key in {"role", "reviewer_role", "author_role"}
                            and child in ("dietitian", "physician"))):
                    raise ManualGraphError("non_medical_reference forbids clinical approval or reviewer roles")
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    for document in documents:
        visit(document)


def validate_metadata(document, policy):
    if any(document.get(key) != value or type(document.get(key)) is not type(value)
           for key, value in metadata(policy).items()):
        raise ManualGraphError("review policy metadata is missing or inconsistent")


def add_argument(parser):
    parser.add_argument("--review-policy", choices=POLICIES, default=DEFAULT)
