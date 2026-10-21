using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class RecommendMealsCommandHandler(NutritionWriteScope scope, MealPreparationService meals)
    : IRequestHandler<RecommendMealsCommand, Result<ResourceResponse>>
{
    public Task<Result<ResourceResponse>> Handle(RecommendMealsCommand request, CancellationToken ct) =>
        scope.ExecuteAsync(request, true, (session, snapshot) =>
            scope.CreateAsync(session, request, snapshot, "recommendation", () => RecommendAsync(session, request, snapshot, ct), ct), ct);

    private async Task<Result<NutritionResourceDraft>> RecommendAsync(INutritionSession session,
        RecommendMealsCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        var prepared = await meals.PrepareAsync(session, request.BeneficiaryId, request.Input, snapshot, null, ct);
        if (prepared.IsFailure) return prepared.Error;
        var meal = prepared.Value;
        var chosen = meal.Eligibility.State == "eligible"
            ? MealConstraintPolicy.Choose(meal.Recipes, meal.Analyzed.Facts, meal.Rules,
                meal.Health.Evidence.GetValueOrDefault("dietaryPattern", "regular"),
                meal.Health.Evidence.GetValueOrDefault("nutritionGoal", "maintain")) : null;
        var payload = meal.Complete(chosen);
        return new NutritionResourceDraft(payload.Decision.State, NutritionJson.Write(payload));
    }
}
