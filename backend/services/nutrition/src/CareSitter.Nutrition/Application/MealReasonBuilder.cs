using System.Globalization;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

// Only reports checks performed by Matches and signals supplied to CandidateSets.
// Retrieval hits are not proof of a clinical claim and are never linked by similarity here.
internal static class MealReasonBuilder
{
    public static MealVerifiedReason[] Build(Recipe[] meals, MealRecommendationRequest request)
    {
        if (!MealConstraintPolicy.Matches(meals, request.Facts, request.Rules, request.DietaryPattern)) return [];
        var reasons = new List<MealVerifiedReason>();
        foreach (var meal in meals)
        {
            foreach (var fact in request.Facts.Where(f => f.Subject == "beneficiary" && f.Kind == "food_allergy" &&
                         f.Assertion != "absent" && f.Temporality != "past" && !string.IsNullOrWhiteSpace(f.Label)))
                reasons.Add(new(meal.VersionId, "declared_allergy_filter", fact.Label) { SourceField = fact.SourceKey });
            if (request.DietaryPattern == "vegetarian")
                reasons.Add(new(meal.VersionId, "dietary_pattern", "vegetarian") { SourceField = "healthHistory/nutrition/dietaryPattern" });
        }
        // Whole-menu scope: a daily nutrient constraint must not be described as a single-meal check.
        foreach (var rule in request.Rules.Where(r => request.Facts.Any(f => f.Subject == "beneficiary" &&
                     f.Kind == "condition" && f.Code == r.ConditionCode && f.Assertion == "present" && f.Temporality == "current")))
        {
            var fact = request.Facts.First(f => f.Subject == "beneficiary" && f.Kind == "condition" &&
                f.Code == rule.ConditionCode && f.Assertion == "present" && f.Temporality == "current");
            foreach (var maximum in rule.DailyMaximums)
                AddRule($"{fact.Label}: tổng {maximum.Key} của 3 bữa = {Number(meals.Sum(m => m.Nutrients[maximum.Key]!.Value))}; giới hạn tối đa theo quy tắc = {Number(maximum.Value)} (cùng đơn vị dữ liệu).");
            foreach (var constraint in rule.NutrientConstraints ?? [])
            {
                var selected = constraint.Scope == "daily" ? meals : meals.Where(m => m.MealType == constraint.MealType).ToArray();
                var actual = selected.Sum(m => m.Nutrients[constraint.NutrientKey]!.Value);
                AddRule($"{fact.Label}: {constraint.NutrientKey} ({(constraint.Scope == "daily" ? "3 bữa" : constraint.MealType)}) = {Number(actual)}; tối thiểu {Optional(constraint.Minimum)}, tối đa {Optional(constraint.Maximum)} (cùng đơn vị dữ liệu).");
            }
            if (rule.ExcludedIngredients.Length > 0)
                AddRule($"{fact.Label}: không có mã nguyên liệu bị loại theo quy tắc: {string.Join(", ", rule.ExcludedIngredients)}.");
            void AddRule(string detail) => reasons.Add(new(Guid.Empty, "condition_rule", detail)
                { SourceField = fact.SourceKey, RuleVersionId = rule.VersionId, SourceIds = rule.Sources });
        }
        if (request.NutritionGoal is "lose" or "gain" or "maintain")
            reasons.Add(new(Guid.Empty, "goal_ranking_signal", request.NutritionGoal)
                { SourceField = "healthHistory/nutrition/nutritionGoal" });
        if (request.Preferences is { } preferences)
        {
            foreach (var item in preferences.PreferredFoods)
                reasons.Add(new(Guid.Empty, "preferred_food_signal", item) { SourceField = "healthHistory/nutrition/preferredFoods" });
            foreach (var item in preferences.DislikedFoods)
                reasons.Add(new(Guid.Empty, "disliked_food_signal", item) { SourceField = "healthHistory/nutrition/dislikedFoods" });
        }
        return reasons.DistinctBy(r => (r.RecipeVersionId, r.Code, r.Detail, r.RuleVersionId)).ToArray();
    }

    private static string Number(decimal value) => value.ToString("0.##", CultureInfo.InvariantCulture);
    private static string Optional(decimal? value) => value is { } number ? Number(number) : "không đặt";
}
