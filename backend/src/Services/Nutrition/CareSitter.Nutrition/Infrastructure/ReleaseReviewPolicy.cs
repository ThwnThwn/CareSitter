using System.Text.Json;

namespace CareSitter.Nutrition.Infrastructure;

internal static class ReleaseReviewPolicy
{
    public const string Reference = "non_medical_reference";
    public const string Clinical = "source_and_clinical";
    public const string NotAllowed = "grounding_non_medical_reference_not_allowed";

    // Call only after the containing artifact's digest/integrity has been checked.
    public static string Read(JsonElement root)
    {
        var policy = root.GetProperty("review_policy").GetString();
        if (policy is not (Reference or Clinical))
            throw new InvalidOperationException("Release review policy is invalid.");
        var reference = policy == Reference;
        if (root.GetProperty("intended_use").GetString() !=
                (reference ? "academic_reference_non_medical" : "reviewed_nutrition_reference") ||
            root.GetProperty("clinical_review_performed").GetBoolean() == reference ||
            root.GetProperty("independent_clinical_review").GetBoolean() == reference ||
            root.GetProperty("production_public_release").GetBoolean() ||
            (reference && root.GetProperty("clinical_review_not_performed_reason").GetString() !=
                "no_clinical_reviewer_non_medical_reference"))
            throw new InvalidOperationException("Release review metadata is inconsistent.");
        return policy;
    }
}
