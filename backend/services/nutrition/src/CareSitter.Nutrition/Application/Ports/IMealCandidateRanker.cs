using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public interface IMealCandidateRanker
{
    Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request, CancellationToken ct);
}

public sealed record MealCandidateRankingRequest(long CatalogRevision, Recipe[][] CandidateSets,
    IReadOnlyList<HealthFact> Facts, IReadOnlyList<DietaryRule> Rules,
    MealRecommendationEvidence[] Evidence, string DietaryPattern, string NutritionGoal,
    Recipe[]? RecentMeals = null);

public sealed record MealCandidateRankingResult(bool Available, Guid[] SelectedRecipeVersionIds,
    string? Model, string? PromptVersion, MealRecommendationExplanation[] Explanations, string[] Warnings)
{
    public static MealCandidateRankingResult Unavailable(string warning) =>
        new(false, [], null, null, [], [warning]);
}
