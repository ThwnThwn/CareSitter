using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Nutrition;

/// <summary>Nhận nguồn món đã được use case thực đơn của gia đình xác minh.</summary>
public interface IMealTasteFeedbackService
{
    Task<Result<MealTasteFeedbackResponse>> SubmitAsync(MealTasteFeedbackProposal proposal, CancellationToken ct);
}

public sealed record MealTasteFeedbackProposal(Guid OwnerId, Guid BeneficiaryId, Guid PlanId,
    DateOnly PlannedDate, Guid RecipeVersionId, string MealType, string MealName, string Feedback,
    Guid IdempotencyKey);

public sealed record MealTasteFeedbackResponse(Guid Id, Guid PlanId, Guid RecipeVersionId, string MealType,
    string MealName, string Feedback, string Status, string SubmittedByRole, DateTimeOffset SubmittedAt,
    DateTimeOffset? ReviewedAt, long? AppliedHealthRevision);
