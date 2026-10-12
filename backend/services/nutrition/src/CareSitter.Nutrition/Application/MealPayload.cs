using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public sealed record MealPayload(int SchemaVersion, Guid AssessmentId, DateOnly PlannedDate,
    Recipe[] Meals, Guid[] AppliedRules, NutritionDecision Decision, long CatalogRevision = 0);
