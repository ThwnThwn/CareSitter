using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class RecommendMealsCommandHandler(NutritionWriteScope scope, MealPreparationService meals,
    IMealRecommendationEngine recommendations)
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
        MealRecommendationResult? recommendation = null;
        if (meal.Eligibility.State == "eligible")
        {
            var history = await session.PlansAsync(request.BeneficiaryId, ct);
            var recentMeals = history.Select(plan => NutritionJson.Read<MealPayload>(plan.Payload))
                .Where(plan => plan.PlannedDate <= meal.PlannedDate &&
                    plan.PlannedDate >= meal.PlannedDate.AddDays(-7))
                .GroupBy(plan => plan.PlannedDate)
                .Select(group => group.First())
                .OrderByDescending(plan => plan.PlannedDate)
                .Take(3)
                .SelectMany(plan => plan.Meals).ToArray();
            recommendation = await recommendations.RecommendAsync(new MealRecommendationRequest(
                meal.CatalogRevision, meal.Recipes, meal.Analyzed.Facts, meal.Rules,
                meal.Health.Evidence.GetValueOrDefault("dietaryPattern", "regular"),
                meal.Health.Evidence.GetValueOrDefault("nutritionGoal", "maintain"), recentMeals), ct);
        }
        var payload = meal.Complete(recommendation?.Meals) with
        {
            RecommendationTrace = recommendation?.Trace
        };
        return new NutritionResourceDraft(payload.Decision.State, NutritionJson.Write(payload));
    }
}
