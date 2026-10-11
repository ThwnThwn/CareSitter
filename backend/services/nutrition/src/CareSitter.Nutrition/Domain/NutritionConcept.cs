namespace CareSitter.Nutrition.Domain;

public sealed record NutritionConcept(string Code, string Kind, string[] Aliases, int Version);
