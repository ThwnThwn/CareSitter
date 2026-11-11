using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class MealConstraintPolicy
{
    // Composite or processed ingredients without pinned commercial allergen/composition specifications.
    private static readonly HashSet<string> UnverifiedCompositeIngredients =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "CHILI_SAUCE",
            "FERMENTED_SOYBEAN_RICE",
            "TOFU_BOILED",
            "RICE_NOODLE_READY",
            "GLASS_NOODLE_DRY"
        };

    // Defense in depth: filtering must still work if a catalog recipe forgets the derived allergen label.
    private static readonly IReadOnlyDictionary<string, HashSet<string>> AllergenIngredientCodes =
        new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["PEANUT"] = new(StringComparer.OrdinalIgnoreCase) { "PEANUT_OIL" },
            ["BEEF"] = new(StringComparer.OrdinalIgnoreCase) { "BEEF_LEAN_RAW" },
            ["CHICKEN"] = new(StringComparer.OrdinalIgnoreCase) { "CHICKEN_RAW" }
        };

    public static bool ValidRecipe(Recipe r) => r.MealType is "breakfast" or "lunch" or "dinner" &&
        !string.IsNullOrWhiteSpace(r.Name) &&
        r.Servings == 1 && r.Ingredients is { Length: > 0 } &&
        r.Allergens is not null && r.AllergenDataComplete && r.Nutrients is not null &&
        r.PreparationSteps is { Length: > 0 } && r.PreparationSteps.All(s => !string.IsNullOrWhiteSpace(s)) &&
        r.Allergens.All(s => !string.IsNullOrWhiteSpace(s)) &&
        r.Sources is { Length: > 0 } && r.Sources.All(s => !string.IsNullOrWhiteSpace(s)) &&
        r.Ingredients.All(i => i is not null && !string.IsNullOrWhiteSpace(i.Code) &&
            !UnverifiedCompositeIngredients.Contains(i.Code) &&
            !string.IsNullOrWhiteSpace(i.Name) && i.Amount > 0 &&
            i.Unit is "g" or "ml" && i.Basis is "raw" or "cooked") &&
        r.Nutrients.All(p => p.Value is null || p.Value >= 0);

    public static bool Matches(IReadOnlyList<Recipe> meals, IReadOnlyList<HealthFact> facts,
        IReadOnlyList<DietaryRule> rules, string dietaryPattern = "regular")
    {
        if (meals.Count != 3 || meals.Select(m => m.MealType).Distinct().Count() != 3 || meals.Any(m => !ValidRecipe(m))) return false;
        if (!MatchesDietaryPattern(meals, dietaryPattern)) return false;
        var allergies = facts.Where(f => f.Subject == "beneficiary" && f.Kind == "food_allergy" &&
            f.Assertion != "absent" && f.Temporality != "past").Select(f => f.Code)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (meals.Any(m => m.Allergens.Any(allergies.Contains))) return false;
        if (allergies.Any(allergy => AllergenIngredientCodes.TryGetValue(allergy, out var ingredientCodes) &&
                meals.Any(meal => meal.Ingredients.Any(ingredient => ingredientCodes.Contains(ingredient.Code))))) return false;
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
        int maximum = 12, IReadOnlyList<Recipe>? recentMeals = null,
        IReadOnlyList<Recipe[]>? previousMenus = null, IReadOnlyList<Recipe>? yesterdayMeals = null,
        string? varietySeed = null)
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
        if (previousMenus is { Count: > 0 })
        {
            var previousIds = previousMenus.Select(MenuIds).ToHashSet(StringComparer.Ordinal);
            var previousNames = previousMenus.Select(MenuNames).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var newMenus = candidates.Where(set => !previousIds.Contains(MenuIds(set)) &&
                !previousNames.Contains(MenuNames(set))).ToList();
            if (newMenus.Count > 0) candidates = newMenus;
        }
        // Apply variety before the shortlist: otherwise all twelve sets can repeat yesterday's meals.
        // Never relax allergies, dietary pattern or nutrient constraints to achieve variety.
        // Newer dishes weigh more than older ones: the fewest repeats of yesterday, then of the
        // recent window, then of every remembered menu (up to six days).
        if (yesterdayMeals is { Count: > 0 })
            candidates = KeepFewestRepeats(candidates, yesterdayMeals);
        if (recentMeals is { Count: > 0 })
            candidates = KeepFewestRepeats(candidates, recentMeals);
        if (previousMenus is { Count: > 0 })
            candidates = KeepFewestRepeats(candidates, previousMenus.SelectMany(menu => menu).ToArray());
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
        var final = varietySeed is null ? ordered.ToArray() : ShuffleEnergyBand(ordered.ToArray(), varietySeed);
        return final.Take(maximum).Select(value => value.Meals).ToArray();
    }

    // Menus whose total energy is within this fraction of the goal's target are treated as equally good.
    internal const decimal VarietyEnergyBand = 0.10m;

    private static List<Recipe[]> KeepFewestRepeats(List<Recipe[]> candidates, IReadOnlyList<Recipe> meals)
    {
        var ids = meals.Select(meal => meal.VersionId).ToHashSet();
        var names = meals.Select(meal => CanonicalName(meal.Name)).ToHashSet(StringComparer.OrdinalIgnoreCase);
        int Repeats(Recipe[] set) => set.Count(meal => ids.Contains(meal.VersionId) ||
            names.Contains(CanonicalName(meal.Name)));
        var minimum = candidates.Min(Repeats);
        return candidates.Where(set => Repeats(set) == minimum).ToList();
    }

    // Seeded shuffle of the menus closest to the goal. The first entry is the goal's best menu, so its
    // energy is the target. The seed (beneficiary + date + catalog revision) changes the order every day
    // while keeping a repeated request on the same day stable. SHA-256 keeps it identical across runtimes.
    private static RankedCandidate[] ShuffleEnergyBand(RankedCandidate[] ordered, string seed)
    {
        if (ordered.Length < 2) return ordered;
        var target = ordered[0].Energy!.Value;
        var tolerance = Math.Abs(target) * VarietyEnergyBand;
        bool InBand(RankedCandidate value) => Math.Abs(value.Energy!.Value - target) <= tolerance;
        var band = ordered.Where(InBand)
            .OrderBy(value => VarietyKey(seed, value.Meals), StringComparer.Ordinal)
            .ToArray();
        return [.. band, .. ordered.Where(value => !InBand(value))];
    }

    private static string VarietyKey(string seed, IEnumerable<Recipe> meals) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(seed + "\n" + MenuIds(meals))));

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

    private static string MenuIds(IEnumerable<Recipe> meals) =>
        string.Join("|", meals.OrderBy(meal => meal.MealType).Select(meal => meal.VersionId));

    private static string MenuNames(IEnumerable<Recipe> meals) =>
        string.Join("|", meals.OrderBy(meal => meal.MealType).Select(meal => CanonicalName(meal.Name)));

    private static string CanonicalName(string name) => name.Trim().StartsWith("[DEMO]", StringComparison.OrdinalIgnoreCase)
        ? name.Trim()[6..].Trim() : name.Trim();
}
