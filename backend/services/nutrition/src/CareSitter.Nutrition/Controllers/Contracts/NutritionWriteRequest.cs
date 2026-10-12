namespace CareSitter.Nutrition.Controllers;

public sealed record NutritionWriteRequest(long ExpectedHealthRevision, Guid IdempotencyKey,
    Guid? AssessmentId = null, DateOnly? PlannedDate = null, Guid? RecommendationId = null,
    Guid? RecipeVersionId = null, string? MealType = null);
