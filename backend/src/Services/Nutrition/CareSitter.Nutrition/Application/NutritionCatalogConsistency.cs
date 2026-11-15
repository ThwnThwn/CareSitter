using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

internal static class NutritionCatalogConsistency
{
    public static bool ContentCurrent(MealPayload payload, IReadOnlyList<Recipe> recipes, IReadOnlyList<DietaryRule> rules) =>
        payload.Meals.All(m => recipes.Any(r => r.VersionId == m.VersionId && Comparable(r) == Comparable(m))) &&
        payload.AppliedRules.All(id => rules.Any(r => r.VersionId == id && NutritionEligibilityPolicy.ValidRule(r)));

    private static string Comparable(Recipe recipe) => NutritionJson.Write(recipe with { SourceDetails = null });
}
