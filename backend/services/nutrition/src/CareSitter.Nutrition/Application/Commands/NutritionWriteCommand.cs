using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

public abstract record NutritionWriteCommand(Guid BeneficiaryId, NutritionWriteInput Input)
    : IRequest<Result<ResourceResponse>>
{
    public Guid IdempotencyKey => Input.IdempotencyKey;
}

public sealed record NutritionWriteInput(long ExpectedHealthRevision, Guid IdempotencyKey,
    Guid? AssessmentId = null, DateOnly? PlannedDate = null, Guid? RecipeVersionId = null, string? MealType = null)
{
    // Earlier gRPC commands included this optional field in the persisted hash
    // even for assessment/recommendation requests that do not use a resource.
    internal Guid? FingerprintResourceId { get; init; }
}
