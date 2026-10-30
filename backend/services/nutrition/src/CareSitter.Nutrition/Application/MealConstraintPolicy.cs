using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class MealConstraintPolicy
{
    public static bool ValidRecipe(Recipe r) => r.MealType is "breakfast" or "lunch" or "dinner" &&
        !string.IsNullOrWhiteSpace(r.Name) && r.Servings == 1 && r.Ingredients is { Length: > 0 } &&
        r.Allergens is not null && r.AllergenDataComplete && r.Nutrients is not null &&
        r.PreparationSteps is { Length: > 0 } && r.PreparationSteps.All(s => !string.IsNullOrWhiteSpace(s)) &&
        r.Allergens.All(s => !string.IsNullOrWhiteSpace(s)) &&
        r.Sources is { Length: > 0 } && r.Sources.All(s => !string.IsNullOrWhiteSpace(s)) &&
        r.Ingredients.All(i => i is not null && !string.IsNullOrWhiteSpace(i.Code) && !string.IsNullOrWhiteSpace(i.Name) && i.Amount > 0 &&
            i.Unit is "g" or "ml" && i.Basis is "raw" or "cooked") && r.Nutrients.All(p => p.Value is null || p.Value >= 0);

    public static bool Matches(IReadOnlyList<Recipe> meals, IReadOnlyList<HealthFact> facts,
        IReadOnlyList<DietaryRule> rules, string dietaryPattern = "regular")
    {
        if (meals.Count != 3 || meals.Select(m => m.MealType).Distinct().Count() != 3 || meals.Any(m => !ValidRecipe(m))) return false;
        if (!MatchesDietaryPattern(meals, dietaryPattern)) return false;
        var allergies = facts.Where(f => f.Subject == "beneficiary" && f.Kind == "food_allergy" &&
            f.Assertion != "absent" && f.Temporality != "past").Select(f => f.Code).ToHashSet();
        if (meals.Any(m => m.Allergens.Any(allergies.Contains))) return false;
        var conditions = facts.Where(f => f.Subject == "beneficiary" && f.Kind == "condition" &&
            f.Assertion == "present" && f.Temporality == "current").Select(f => f.Code).ToHashSet();
        foreach (var rule in rules.Where(r => conditions.Contains(r.ConditionCode)))
        {
            if (!NutritionEligibilityPolicy.ValidRule(rule)) return false;
            if (meals.Any(m => m.Ingredients.Select(i => i.Code).Intersect(rule.ExcludedIngredients, StringComparer.OrdinalIgnoreCase).Any())) return false;
            foreach (var max in rule.DailyMaximums)
            {
                if (meals.Any(m => !m.Nutrients.TryGetValue(max.Key, out var v) || v is null || v < 0)) return false;
                if (meals.Sum(m => m.Nutrients[max.Key]!.Value) > max.Value) return false;
            }
            foreach (var constraint in rule.NutrientConstraints ?? [])
            {
                var constrainedMeals = constraint.Scope == "daily"
                    ? meals
                    : meals.Where(meal => meal.MealType == constraint.MealType).ToArray();
                if (constrainedMeals.Count == 0 ||
                    constrainedMeals.Any(meal => !meal.Nutrients.TryGetValue(constraint.NutrientKey, out var value) || value is null || value < 0)) return false;
                var actual = constrainedMeals.Sum(meal => meal.Nutrients[constraint.NutrientKey]!.Value);
                if (constraint.Minimum is { } minimum && actual < minimum) return false;
                if (constraint.Maximum is { } maximum && actual > maximum) return false;
            }
        }
        return true;
    }

    public static Recipe[]? Choose(IReadOnlyList<Recipe> recipes, IReadOnlyList<HealthFact> facts,
        IReadOnlyList<DietaryRule> rules, string dietaryPattern = "regular", string nutritionGoal = "maintain")
    {
        return CandidateSets(recipes, facts, rules, dietaryPattern, nutritionGoal, 1).FirstOrDefault();
    }

    public static Recipe[][] CandidateSets(IReadOnlyList<Recipe> recipes, IReadOnlyList<HealthFact> facts,
        IReadOnlyList<DietaryRule> rules, string dietaryPattern = "regular", string nutritionGoal = "maintain",
        int maximum = 12, IReadOnlyList<Recipe>? recentMeals = null)
    {
        if (maximum < 1) throw new ArgumentOutOfRangeException(nameof(maximum));
        // Bounded catalog avoids unbounded combinations. No constraint is dropped to find a result.
        var usable = recipes.Where(ValidRecipe).ToArray();
        var candidates = new List<Recipe[]>();
        foreach (var a in usable.Where(r => r.MealType == "breakfast").Take(30))
            foreach (var b in usable.Where(r => r.MealType == "lunch").Take(30))
                foreach (var c in usable.Where(r => r.MealType == "dinner").Take(30))
                    if (Matches([a, b, c], facts, rules, dietaryPattern)) candidates.Add([a, b, c]);
        if (candidates.Count == 0) return [];
        // Apply variety before the shortlist: otherwise all twelve sets can repeat yesterday's meals.
        // Never relax allergies, dietary pattern or nutrient constraints to achieve variety.
        if (recentMeals is { Count: > 0 })
        {
            var recentIds = recentMeals.Select(meal => meal.VersionId).ToHashSet();
            var recentNames = recentMeals.Select(meal => CanonicalName(meal.Name)).ToHashSet(StringComparer.OrdinalIgnoreCase);
            int Repeats(Recipe[] set) => set.Count(meal => recentIds.Contains(meal.VersionId) ||
                recentNames.Contains(CanonicalName(meal.Name)));
            var minimumRepeats = candidates.Min(Repeats);
            candidates = candidates.Where(set => Repeats(set) == minimumRepeats).ToList();
        }
        var ranked = candidates
            .Select((meals, index) => new RankedCandidate(meals, TotalEnergy(meals), index))
            .Where(value => value.Energy is not null)
            .ToArray();
        if (ranked.Length == 0) return candidates.Take(maximum).ToArray();
        var ordered = nutritionGoal switch
        {
            "lose" => ranked.OrderBy(value => value.Energy).ThenBy(value => value.Index),
            "gain" => ranked.OrderByDescending(value => value.Energy).ThenBy(value => value.Index),
            _ => OrderAroundMedian(ranked)
        };
        return ordered.Take(maximum).Select(value => value.Meals).ToArray();
    }

    public static IEnumerable<Recipe> OrderForGoal(IEnumerable<Recipe> recipes, string nutritionGoal)
    {
        var values = recipes.Select((recipe, index) => new { Recipe = recipe, Energy = Energy(recipe), Index = index }).ToArray();
        var known = values.Where(value => value.Energy is not null).OrderBy(value => value.Energy).ToArray();
        if (known.Length == 0) return values.OrderBy(value => value.Index).Select(value => value.Recipe);
        var median = known[known.Length / 2].Energy!.Value;
        return nutritionGoal switch
        {
            "lose" => values.OrderBy(value => value.Energy is null).ThenBy(value => value.Energy).ThenBy(value => value.Index).Select(value => value.Recipe),
            "gain" => values.OrderBy(value => value.Energy is null).ThenByDescending(value => value.Energy).ThenBy(value => value.Index).Select(value => value.Recipe),
            _ => values.OrderBy(value => value.Energy is null).ThenBy(value => value.Energy is null ? decimal.MaxValue : Math.Abs(value.Energy.Value - median))
                .ThenBy(value => value.Index).Select(value => value.Recipe)
        };
    }

    private static bool MatchesDietaryPattern(IEnumerable<Recipe> meals, string dietaryPattern) => dietaryPattern switch
    {
        "regular" => true,
        "vegetarian" => meals.All(meal => meal.DietaryPatterns?.Contains("vegetarian", StringComparer.Ordinal) == true),
        _ => false
    };

    private static decimal? TotalEnergy(IEnumerable<Recipe> meals)
    {
        decimal total = 0;
        foreach (var meal in meals)
        {
            var energy = Energy(meal);
            if (energy is null) return null;
            total += energy.Value;
        }
        return total;
    }

    private static decimal? Energy(Recipe recipe) =>
        recipe.Nutrients.TryGetValue("energy_kcal", out var value) && value is >= 0 ? value : null;

    private static IOrderedEnumerable<RankedCandidate> OrderAroundMedian(RankedCandidate[] ranked)
    {
        var sorted = ranked.OrderBy(value => value.Energy).ThenBy(value => value.Index).ToArray();
        var baseline = sorted[sorted.Length / 2];
        var median = baseline.Energy!.Value;
        return ranked.OrderBy(value => value.Index == baseline.Index ? 0 : 1)
            .ThenBy(value => Math.Abs(value.Energy!.Value - median)).ThenBy(value => value.Index);
    }

    private sealed record RankedCandidate(Recipe[] Meals, decimal? Energy, int Index);

    private static string CanonicalName(string name) => name.Trim().StartsWith("[DEMO]", StringComparison.OrdinalIgnoreCase)
        ? name.Trim()[6..].Trim() : name.Trim();
}
