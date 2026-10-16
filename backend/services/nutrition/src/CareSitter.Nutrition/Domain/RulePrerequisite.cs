namespace CareSitter.Nutrition.Domain;

public sealed record RulePrerequisite(
    string Field,
    string Operator,
    string[] Values,
    string EvidenceSource = "health_profile",
    string? Unit = null,
    int? MaxAgeDays = null);
