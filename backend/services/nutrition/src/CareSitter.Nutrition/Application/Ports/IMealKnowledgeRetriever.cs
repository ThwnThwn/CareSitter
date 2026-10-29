namespace CareSitter.Nutrition.Application;

public interface IMealKnowledgeRetriever
{
    Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct);
}

public sealed record MealKnowledgeRequest(string[] Conditions, string[] Nutrients,
    string[] Ingredients, string DietaryPattern, string NutritionGoal);

public sealed record MealKnowledgeResult(bool Available, string? Revision, string? Strategy,
    MealRecommendationEvidence[] Evidence, string[] Warnings)
{
    public static MealKnowledgeResult Unavailable(string warning) =>
        new(false, null, null, [], [warning]);
}
