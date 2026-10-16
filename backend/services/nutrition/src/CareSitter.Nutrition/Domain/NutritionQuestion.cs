namespace CareSitter.Nutrition.Domain;

public sealed record NutritionQuestion(string Id, string SourceField, string InputType,
    string[] Options, bool Required, string Purpose);
