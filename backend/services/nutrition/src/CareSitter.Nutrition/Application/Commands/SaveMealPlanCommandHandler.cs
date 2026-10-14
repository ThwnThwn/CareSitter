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
        return new NutritionResourceDraft("saved", NutritionJson.Write(meal.Complete(meal.Previous!.Meals)));
    }
}
