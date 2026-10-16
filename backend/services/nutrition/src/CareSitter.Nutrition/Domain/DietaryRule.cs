using System.Text.Json.Serialization;

namespace CareSitter.Nutrition.Domain;

public sealed record DietaryRule(Guid VersionId, string ConditionCode, RulePrerequisite[] Prerequisites,
    string[] ExcludedIngredients, Dictionary<string, decimal> DailyMaximums, string[] Sources,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] NutrientConstraint[]? NutrientConstraints = null);
