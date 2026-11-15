using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class MealTasteFeedbackHandlers(IPeopleRepository repository, IMealTasteFeedbackStore store,
    IMealPlanSnapshotReader plans, IMealTasteFeedbackService feedback, ICurrentUser user, IClock clock)
    : IRequestHandler<SubmitMealTasteFeedbackCommand, Result<MealTasteFeedbackResponse>>,
      IRequestHandler<ReviewMealTasteFeedbackCommand, Result<MealTasteFeedbackResponse>>,
      IRequestHandler<ListMealTasteFeedbackQuery, Result<MealTasteFeedbackListResponse>>
{
    public async Task<Result<MealTasteFeedbackResponse>> Handle(SubmitMealTasteFeedbackCommand request, CancellationToken ct)
    {
        if (!Owner(out var actor)) return Forbidden();
        var source = await plans.ReadForFeedbackAsync(request.BeneficiaryId, request.PlanId, ct);
        if (source.IsFailure) return source.Error;
        var plan = source.Value;
        if (plan.Id != request.PlanId || plan.BeneficiaryId != request.BeneficiaryId) return Forbidden();
        var meal = plan.Meals.SingleOrDefault(x => x.VersionId == request.RecipeVersionId);
        if (meal is null) return MealTasteFeedbackService.Missing();
        return await feedback.SubmitAsync(new(actor, request.BeneficiaryId, plan.Id, plan.PlannedDate,
            meal.VersionId, meal.MealType, meal.Name, request.Feedback, request.IdempotencyKey), ct);
    }

    public async Task<Result<MealTasteFeedbackListResponse>> Handle(ListMealTasteFeedbackQuery request, CancellationToken ct)
    {
        if (!Owner(out var actor)) return Forbidden();
        if (request.PlanId == Guid.Empty) return Error.Validation("nutrition.feedback_invalid", "Vui lòng chọn thực đơn.");
        await using var transaction = await repository.BeginUserScopeAsync(actor, ct);
        var beneficiary = await repository.GetBeneficiaryAsync(request.BeneficiaryId, actor, ct);
        if (beneficiary is null) return MealTasteFeedbackService.Missing();
        var items = await store.ListAsync(actor, request.BeneficiaryId, request.PlanId, ct);
        return new MealTasteFeedbackListResponse(items.Select(MealTasteFeedbackService.Map).ToArray(), beneficiary.HealthProfileRevision);
    }

    public async Task<Result<MealTasteFeedbackResponse>> Handle(ReviewMealTasteFeedbackCommand request, CancellationToken ct)
    {
        if (!Owner(out var actor)) return Forbidden();
        await using var transaction = await repository.BeginUserScopeAsync(actor, ct);
        var beneficiary = await repository.GetBeneficiaryAsync(request.BeneficiaryId, actor, ct);
        if (beneficiary is null) return MealTasteFeedbackService.Missing();
        var item = await store.FindAsync(actor, request.BeneficiaryId, request.FeedbackId, ct);
        if (item is null) return MealTasteFeedbackService.Missing();
        if (item.Status != "pending")
            return item.Status == (request.Approve ? "approved" : "rejected") ? MealTasteFeedbackService.Map(item) :
                Error.Conflict("nutrition.feedback_reviewed", "Phản hồi đã được xử lý. Vui lòng tải lại.");
        if (request.Approve)
        {
            if (request.ExpectedHealthRevision < 1 || beneficiary.HealthProfileRevision != request.ExpectedHealthRevision)
                return Error.Conflict("nutrition.profile_changed", "Sở thích hoặc hồ sơ đã đổi. Vui lòng tải lại trước khi duyệt.");
            var history = MealTastePreferences.Apply(beneficiary.HealthHistory, item.MealName, item.Feedback != "disliked");
            if (history.IsFailure) return history.Error;
            var changed = beneficiary.UpdateHealth(request.ExpectedHealthRevision, beneficiary.GeneralNote,
                beneficiary.CareInstructions, history.Value, beneficiary.Allergies, beneficiary.ChronicConditions,
                beneficiary.Medications, beneficiary.FoodAllergyStatus, actor, clock.UtcNow);
            if (changed.IsFailure) return changed.Error;
            await repository.SaveChangesAsync(ct);
        }
        item.Review(request.Approve, actor, clock.UtcNow, request.Approve ? beneficiary.HealthProfileRevision : null);
        await repository.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return MealTasteFeedbackService.Map(item);
    }

    private bool Owner(out Guid actor) { actor = user.UserId ?? Guid.Empty; return actor != Guid.Empty && user.IsInRole("CUSTOMER"); }
    private static Error Forbidden() => Error.Forbidden("nutrition.feedback_forbidden", "Chỉ gia đình sở hữu hồ sơ được xem và duyệt phản hồi.");
}
