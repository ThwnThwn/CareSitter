namespace CareSitter.Nutrition.Domain;

public sealed record HealthFact(string Kind, string Code, string Label, string Assertion,
    string Temporality, string SourceKey, string Quote, string Subject = "unknown");
