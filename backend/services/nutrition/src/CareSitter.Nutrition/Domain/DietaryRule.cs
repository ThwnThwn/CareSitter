namespace CareSitter.Nutrition.Domain;

public sealed record DietaryRule(Guid VersionId, string ConditionCode, string[] Prerequisites,
    string[] ExcludedIngredients, Dictionary<string, decimal> DailyMaximums, string[] Sources);
