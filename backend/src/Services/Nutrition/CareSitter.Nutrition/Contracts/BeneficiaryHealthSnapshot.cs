using System.Text.Json;

namespace CareSitter.Nutrition.Contracts;

public sealed record BeneficiaryHealthSnapshot(Guid BeneficiaryId, long Revision,
    DateOnly? DateOfBirth, string AllergyStatus, DateTimeOffset? AllergyConfirmedAt,
    string? GeneralNote, string? CareInstructions, string? MobilityNote, string? CareLevel,
    JsonElement? HealthHistory, JsonElement? Allergies, JsonElement? ChronicConditions,
    JsonElement? Medications);
