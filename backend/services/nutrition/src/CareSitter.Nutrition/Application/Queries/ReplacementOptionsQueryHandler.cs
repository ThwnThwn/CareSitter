using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class ReplacementOptionsQueryHandler(IPeopleHealthClient people, INutritionStore store,
    ICurrentUser user, INutritionFeatures features) : IRequestHandler<ReplacementOptionsQuery, Result<IReadOnlyList<Recipe>>>
{
    public async Task<Result<IReadOnlyList<Recipe>>> Handle(ReplacementOptionsQuery request, CancellationToken ct)
    {
        if (NutritionAccessRules.Check(user, features) is { } error) return error;
        if (!features.RecommendationsEnabled)
            return Error.Unavailable("nutrition.recommendations_disabled", "Gợi ý thực đơn chưa được mở.");
        if (request.MealType is not ("breakfast" or "lunch" or "dinner"))
            return Error.Validation("nutrition.meal_type", "Bữa ăn không hợp lệ.");
        var source = await people.ReadAsync(user.UserId!.Value, request.BeneficiaryId, ct);
        if (source is null) return NutritionAccessRules.Missing();
        var response = await store.InOwnerScopeAsync<Result<IReadOnlyList<Recipe>>>(user.UserId.Value, async session =>
        {
            var resource = await session.GetAsync("recommendation", request.BeneficiaryId, request.RecommendationId, ct);
            if (resource is null) return NutritionAccessRules.Missing();
            if (resource.HealthRevision != source.Revision) return NutritionAccessRules.Changed();
            var meal = NutritionJson.Read<MealPayload>(resource.Payload);
            if (resource.Status != "suggested")
                return Error.Conflict("nutrition.not_suggested", "Chưa có thực đơn để đổi món.");
            var assessment = await session.GetAsync("assessment", request.BeneficiaryId, meal.AssessmentId, ct);
            if (assessment is null) return NutritionAccessRules.Missing();
            if (assessment.HealthRevision != source.Revision || assessment.Status != "confirmed")
                return NutritionAccessRules.Changed();
            var analyzed = NutritionJson.Read<AssessmentPayload>(assessment.Payload);
            var revision = await session.CatalogRevisionAsync(ct);
            var recipes = await session.RecipesAsync(ct);
            var rules = await session.RulesAsync(ct);
            if (meal.CatalogRevision != revision || analyzed.CatalogRevision != revision ||
                !NutritionCatalogConsistency.ContentCurrent(meal, recipes, rules)) return NutritionAccessRules.ContentChanged();
            var health = HealthSnapshotNormalizer.Normalize(source, await session.ConceptsAsync(ct));
            if (NutritionEligibilityPolicy.Evaluate(source, health, analyzed.Facts, rules, true).State != "eligible")
                return Error.Conflict("nutrition.not_eligible", "Cần kiểm tra lại thông tin sức khỏe.");
            // Chỉ đưa ứng viên khi thay vào vẫn đáp ứng ràng buộc của cả ngày.
            return recipes.Where(r => r.MealType == request.MealType &&
                !meal.Meals.Any(m => m.VersionId == r.VersionId) &&
                MealConstraintPolicy.Matches(meal.Meals.Select(m => m.MealType == request.MealType ? r : m).ToArray(), analyzed.Facts, rules))
                .Take(20).ToArray();
        }, ct);
        var current = await people.ReadAsync(user.UserId.Value, request.BeneficiaryId, ct);
        if (current is null) return NutritionAccessRules.Missing();
        return current.Revision != source.Revision ? NutritionAccessRules.Changed() : response;
    }
}
