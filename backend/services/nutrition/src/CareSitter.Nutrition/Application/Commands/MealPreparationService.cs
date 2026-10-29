using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;

namespace CareSitter.Nutrition.Application;

internal sealed class MealPreparationService
{
    public async Task<Result<MealPreparation>> PrepareAsync(INutritionSession session, Guid beneficiary,
        NutritionWriteInput input, BeneficiaryHealthSnapshot snapshot, Guid? recommendationId, CancellationToken ct)
    {
        MealPayload? previous = null;
        if (recommendationId is { } id)
        {
            var resource = await session.GetAsync("recommendation", beneficiary, id, ct);
            if (resource is null) return NutritionAccessRules.Missing();
            if (resource.HealthRevision != snapshot.Revision) return NutritionAccessRules.Changed();
            previous = NutritionJson.Read<MealPayload>(resource.Payload);
            if (previous.Decision.State != "suggested")
                return Error.Conflict("nutrition.not_suggested", "Chưa có thực đơn để đổi hoặc lưu.");
        }

        var assessment = await session.GetAsync("assessment", beneficiary, previous?.AssessmentId ?? input.AssessmentId ?? Guid.Empty, ct);
        if (assessment is null) return NutritionAccessRules.Missing();
        if (assessment.HealthRevision != snapshot.Revision) return NutritionAccessRules.Changed();
        if (assessment.Status != "confirmed")
            return Error.Conflict("nutrition.not_confirmed", "Vui lòng xác nhận thông tin trước khi xem gợi ý.");
        var analyzed = NutritionJson.Read<AssessmentPayload>(assessment.Payload);
        var revision = await session.CatalogRevisionAsync(ct);
        if (analyzed.CatalogRevision != revision) return NutritionAccessRules.ContentChanged();
        var rules = await session.RulesAsync(ct);
        var recipes = (await session.RecipesAsync(ct)).Where(MealConstraintPolicy.ValidRecipe).ToArray();
        var health = HealthSnapshotNormalizer.Normalize(snapshot, await session.ConceptsAsync(ct));
        var eligibility = NutritionEligibilityPolicy.Evaluate(snapshot, health, analyzed.Facts, rules, true);
        var date = previous?.PlannedDate ?? input.PlannedDate ?? DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        var activeRules = rules.Where(r => analyzed.Facts.Any(f => f.Subject == "beneficiary" && f.Kind == "condition" && f.Assertion == "present"
            && f.Temporality == "current" && f.Code == r.ConditionCode)).Select(r => r.VersionId).Order().ToArray();
        if (eligibility.State == "eligible" && previous is not null &&
            (previous.CatalogRevision != revision || !NutritionCatalogConsistency.ContentCurrent(previous, recipes, rules)
            || !previous.AppliedRules.Order().SequenceEqual(activeRules)))
            return NutritionAccessRules.ContentChanged();

        return new MealPreparation(assessment.Id, date, analyzed, previous, recipes, rules, activeRules, eligibility, revision, health);
    }
}

internal sealed record MealPreparation(Guid AssessmentId, DateOnly PlannedDate, AssessmentPayload Analyzed,
    MealPayload? Previous, Recipe[] Recipes, IReadOnlyList<DietaryRule> Rules, Guid[] ActiveRules,
    NutritionDecision Eligibility, long CatalogRevision, NormalizedHealth Health)
{
    public MealPayload Complete(Recipe[]? meals)
    {
        if (Eligibility.State != "eligible") return new(1, AssessmentId, PlannedDate, [], [], Eligibility);
        var decision = NutritionDecision.Create(meals is not null ? "suggested" : Recipes.Length == 0 ? "no_content" : "no_match",
            meals is not null ? [] : [Recipes.Length == 0 ? "catalog_unavailable" : "constraints_not_matched"]);
        var payload = new MealPayload(1, AssessmentId, PlannedDate, meals ?? [], ActiveRules, decision, CatalogRevision);
        if (meals is null || Previous?.RecommendationTrace is not { } trace) return payload;
        if (Previous.Meals.Select(meal => meal.VersionId).SequenceEqual(meals.Select(meal => meal.VersionId)))
            return payload with { RecommendationTrace = trace };
        // A manual replacement keeps the demo disclosure, but prior AI evidence no longer describes this menu.
        return payload with
        {
            RecommendationTrace = trace with
            {
                Strategy = "rule_manual_replacement", UsedAi = false, Model = null, PromptVersion = null,
                Evidence = [], Explanations = [], GroundingRevision = null,
                Warnings = trace.Warnings.Append("meal_replaced_by_user").Distinct(StringComparer.Ordinal).ToArray()
            }
        };
    }
}
