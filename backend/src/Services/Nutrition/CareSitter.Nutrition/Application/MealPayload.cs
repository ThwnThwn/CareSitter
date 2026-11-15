using CareSitter.Nutrition.Domain;
using System.Text.Json.Serialization;

namespace CareSitter.Nutrition.Application;

public sealed record MealPayload(int SchemaVersion, Guid AssessmentId, DateOnly PlannedDate,
    Recipe[] Meals, Guid[] AppliedRules, NutritionDecision Decision, long CatalogRevision = 0)
{
    public MealRecommendationTrace? RecommendationTrace { get; init; }
    public string[] AvailableIngredients { get; init; } = [];
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool IsSavedPlan { get; init; }
}
