using CareSitter.Contracts.Nutrition;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record SubmitMealTasteFeedbackCommand(Guid BeneficiaryId, Guid PlanId, Guid RecipeVersionId,
    string Feedback, Guid IdempotencyKey) : IRequest<Result<MealTasteFeedbackResponse>>;
public sealed record ReviewMealTasteFeedbackCommand(Guid BeneficiaryId, Guid FeedbackId,
    bool Approve, long ExpectedHealthRevision) : IRequest<Result<MealTasteFeedbackResponse>>;
public sealed record ListMealTasteFeedbackQuery(Guid BeneficiaryId, Guid PlanId) : IRequest<Result<MealTasteFeedbackListResponse>>;
public sealed record MealTasteFeedbackListResponse(IReadOnlyList<MealTasteFeedbackResponse> Items, long HealthRevision);
