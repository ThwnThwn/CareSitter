using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

public sealed record NutritionCommand(string Operation, Guid BeneficiaryId, long ExpectedHealthRevision,
    Guid IdempotencyKey, Guid? ResourceId = null, Guid? AssessmentId = null, DateOnly? PlannedDate = null,
    Guid? RecipeVersionId = null, string? MealType = null) : IRequest<Result<ResourceResponse>>;
