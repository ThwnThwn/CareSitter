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
        scope.InRecommendationScopeAsync(request, () => RecommendAsync(request, ct), ct);

    private async Task<Result<ResourceResponse>> RecommendAsync(RecommendMealsCommand request, CancellationToken ct)
    {
        var prepared = await scope.ExecuteWithSnapshotAsync<PreparedRecommendation>(request, true,
            (session, snapshot) => PrepareAsync(session, request, snapshot, ct), ct,
            value => value.Replay is { } replay
                ? Result.Success(value with { Replay = replay with { Status = "stale" } })
                : NutritionAccessRules.Changed());
        if (prepared.IsFailure) return prepared.Error;
        if (prepared.Value.Replay is { } replay) return replay;

        var meal = prepared.Value.Meal!;
        // Retrieval and remote ranking can be slow. Keep them outside the owner transaction.
        var recommendation = prepared.Value.Input is { } input
            ? await recommendations.RecommendAsync(input, ct) : null;
        var payload = meal.Complete(recommendation?.Meals) with { RecommendationTrace = recommendation?.Trace };
        var draft = new NutritionResourceDraft(payload.Decision.State, NutritionJson.Write(payload));

        return await scope.ExecuteAsync(request, true, (session, snapshot) =>
            scope.CreateAsync(session, request, snapshot, "recommendation", async () =>
            {
                if (await session.CatalogRevisionAsync(ct) != meal.CatalogRevision)
                    return NutritionAccessRules.ContentChanged();
                return draft;
            }, ct), ct);
    }

    private async Task<Result<PreparedRecommendation>> PrepareAsync(INutritionSession session,
        RecommendMealsCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        var replay = await scope.ReplayAsync(session, request, snapshot, "recommendation", ct);
        if (replay is not null)
        {
            if (replay.IsFailure) return replay.Error;
            return new PreparedRecommendation(replay.Value, null, null);
        }

        if (snapshot.Revision != request.Input.ExpectedHealthRevision) return NutritionAccessRules.Changed();
        var prepared = await meals.PrepareAsync(session, request.BeneficiaryId, request.Input, snapshot, null, ct);
        if (prepared.IsFailure) return prepared.Error;
        var meal = prepared.Value;
        if (meal.Eligibility.State != "eligible") return new PreparedRecommendation(null, meal, null);

        var start = DateOnly.FromDayNumber(Math.Max(0, meal.PlannedDate.DayNumber - 6));
        var history = await session.PlansAsync(request.BeneficiaryId, ct, start, meal.PlannedDate);
        var priorPlans = history.Select(plan => NutritionJson.Read<MealPayload>(plan.Payload))
            .Where(plan => plan.PlannedDate < meal.PlannedDate)
            .OrderByDescending(plan => plan.PlannedDate)
            .DistinctBy(plan => plan.PlannedDate)
            .Take(6).ToArray();
        var previousMenus = priorPlans.Select(plan => plan.Meals).ToArray();
        var yesterday = meal.PlannedDate.DayNumber - 1;
        var yesterdayMeals = priorPlans.FirstOrDefault(plan => plan.PlannedDate.DayNumber == yesterday)?.Meals;
        var recentMeals = previousMenus.Take(3).SelectMany(plan => plan).ToArray();
        var input = new MealRecommendationRequest(
            meal.CatalogRevision, meal.Recipes, meal.Analyzed.Facts, meal.Rules,
            meal.Health.Evidence.GetValueOrDefault("dietaryPattern", "regular"),
            meal.Health.Evidence.GetValueOrDefault("nutritionGoal", "maintain"), recentMeals,
            previousMenus, MealPreferences.FromEvidence(meal.Health.Evidence), yesterdayMeals,
            $"{request.BeneficiaryId:N}|{meal.PlannedDate:yyyy-MM-dd}|{meal.CatalogRevision}");
        return new PreparedRecommendation(null, meal, input);
    }

    private sealed record PreparedRecommendation(ResourceResponse? Replay, MealPreparation? Meal,
        MealRecommendationRequest? Input);
}
