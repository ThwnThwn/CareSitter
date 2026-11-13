using System.Text.Json.Serialization;

namespace CareSitter.Nutrition.Domain;

public abstract record ReleaseReviewMetadata
{
    [JsonPropertyName("review_policy"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ReviewPolicy { get; init; }
    [JsonPropertyName("intended_use"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? IntendedUse { get; init; }
    [JsonPropertyName("clinical_review_performed"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? ClinicalReviewPerformed { get; init; }
    [JsonPropertyName("independent_clinical_review"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? IndependentClinicalReview { get; init; }
    [JsonPropertyName("production_public_release"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? ProductionPublicRelease { get; init; }
    [JsonPropertyName("clinical_review_not_performed_reason"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ClinicalReviewNotPerformedReason { get; init; }
}
