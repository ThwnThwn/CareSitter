using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class ReplaceMealCommandHandler(NutritionWriteScope scope, MealPreparationService meals)
    : IRequestHandler<ReplaceMealCommand, Result<ResourceResponse>>
{
    public Task<Result<ResourceResponse>> Handle(ReplaceMealCommand request, CancellationToken ct) =>
        scope.ExecuteAsync(request, true, (session, snapshot) =>
            scope.CreateAsync(session, request, snapshot, "recommendation", () => ReplaceAsync(session, request, snapshot, ct), ct), ct);

    private async Task<Result<NutritionResourceDraft>> ReplaceAsync(INutritionSession session,
        ReplaceMealCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        var prepared = await meals.PrepareAsync(session, request.BeneficiaryId, request.Input, snapshot, request.RecommendationId, ct);
        if (prepared.IsFailure) return prepared.Error;
        var meal = prepared.Value;
        Recipe[]? selected = null;
        if (meal.Eligibility.State == "eligible")
        {
            var dietaryPattern = meal.Health.Evidence.GetValueOrDefault("dietaryPattern", "regular");
            var replacement = meal.Recipes.FirstOrDefault(r =>
                r.VersionId == request.Input.RecipeVersionId && r.MealType == request.Input.MealType);
            if (replacement is null) return NutritionAccessRules.ContentChanged();
            selected = meal.Previous!.Meals.Select(m => m.MealType == request.Input.MealType ? replacement : m).ToArray();
            if (!MealConstraintPolicy.Matches(selected, meal.Analyzed.Facts, meal.Rules, dietaryPattern))
                return Error.Conflict("nutrition.constraint", "Món thay thế không đáp ứng các yêu cầu của toàn bộ thực đơn.");
        }
        var payload = meal.Complete(selected);
        return new NutritionResourceDraft(payload.Decision.State, NutritionJson.Write(payload));
    }
}
