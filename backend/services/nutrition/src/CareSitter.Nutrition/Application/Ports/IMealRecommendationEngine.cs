using System.Text.Json.Serialization;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public interface IMealRecommendationEngine
{
    Task<MealRecommendationResult> RecommendAsync(MealRecommendationRequest request, CancellationToken ct);
}

public sealed record MealRecommendationRequest(long CatalogRevision, Recipe[] CandidateRecipes,
    IReadOnlyList<HealthFact> Facts, IReadOnlyList<DietaryRule> Rules,
    string DietaryPattern, string NutritionGoal, Recipe[]? RecentMeals = null);

public sealed record MealRecommendationResult(Recipe[]? Meals, MealRecommendationTrace Trace);

public sealed record MealRecommendationTrace(int SchemaVersion, string Strategy, bool UsedAi,
    string? Model, string? PromptVersion, MealRecommendationEvidence[] Evidence,
    MealRecommendationExplanation[] Explanations, string[] Warnings,
    string? GroundingRevision = null, string? GroundingStrategy = null);

public sealed record MealRecommendationEvidence(string Id, string Title, string? Chapter,
    string? PrintedPages, string Locator, string Reference,
    [property: JsonIgnore] string? Excerpt = null);

public sealed record MealRecommendationExplanation(Guid RecipeVersionId, string Summary,
    string[] EvidenceIds);
