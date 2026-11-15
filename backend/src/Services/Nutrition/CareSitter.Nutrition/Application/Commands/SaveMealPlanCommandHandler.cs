using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class SaveMealPlanCommandHandler(NutritionWriteScope scope, MealPreparationService meals)
    : IRequestHandler<SaveMealPlanCommand, Result<ResourceResponse>>
{
    public Task<Result<ResourceResponse>> Handle(SaveMealPlanCommand request, CancellationToken ct) =>
        scope.ExecuteAsync(request, true, (session, snapshot) =>
            scope.CreateAsync(session, request, snapshot, "plan", () => SaveAsync(session, request, snapshot, ct), ct), ct);

    private async Task<Result<NutritionResourceDraft>> SaveAsync(INutritionSession session,
        SaveMealPlanCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        var prepared = await meals.PrepareAsync(session, request.BeneficiaryId, request.Input, snapshot, request.RecommendationId, ct);
        if (prepared.IsFailure) return prepared.Error;
        var meal = prepared.Value;
        // A dated save is used by weekly generation, which must preserve an occupied day.
        if (request.Input.PlannedDate is { } date)
        {
            if (date != meal.PlannedDate)
                return Error.Validation("nutrition.request", "Ngày lưu không khớp với ngày gợi ý.");
            if ((await session.PlansAsync(request.BeneficiaryId, ct, date, date)).Count > 0)
                return Error.Conflict("nutrition.plan_date_occupied", "Ngày này đã có thực đơn. Vui lòng tải lại.");
        }
        return new NutritionResourceDraft("saved", NutritionJson.Write(meal.Complete(meal.Previous!.Meals)));
    }
}
