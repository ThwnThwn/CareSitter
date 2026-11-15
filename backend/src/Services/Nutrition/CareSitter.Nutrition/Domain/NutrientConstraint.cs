namespace CareSitter.Nutrition.Domain;

public sealed record NutrientConstraint(
    string NutrientKey,
    string Scope,
    string? MealType,
    decimal? Minimum,
    decimal? Maximum);
