using System.Text;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class MealPantryTests
{
    [Fact]
    public void Names_preserve_accents_whole_words_and_deduplicate_unicode()
    {
        var recipe = Recipe("breakfast", "Cá rô phi");
        Assert.Equal(["cá"], MealPantryPolicy.Matches(recipe, [" CÁ ", "cá".Normalize(NormalizationForm.FormD)]));
        Assert.Empty(MealPantryPolicy.Matches(recipe, ["cà", "ca", "phiên"]));
        Assert.Empty(MealPantryPolicy.Matches(Recipe("lunch", "Gạo"), ["gà"]));
        Assert.False(MealPantryPolicy.Valid(Enumerable.Repeat("cá", 21).ToArray()));
        Assert.False(MealPantryPolicy.Valid([new string('x', 81)]));
        Assert.False(MealPantryPolicy.Valid([" "]));
    }

    [Fact]
    public async Task Available_food_is_prioritized_and_reason_only_claims_actual_ingredient_matches()
    {
        var other = Recipe("breakfast", "Thịt gà");
        var fish = Recipe("breakfast", "Cá rô phi");
        var engine = new MealRecommendationEngine(new UnavailableMealKnowledgeRetriever(), new UnavailableMealCandidateRanker());
        var result = await engine.RecommendAsync(new(1, [other, fish, Recipe("lunch", "Gạo"), Recipe("dinner", "Bí đỏ")],
            [], [], "regular", "maintain", Preferences: new("no_preference", [], []) { AvailableIngredients = ["cá", "trứng"] }), default);
        Assert.Equal(fish.VersionId, result.Meals![0].VersionId);
        var reason = Assert.Single(result.Trace.VerifiedReasons, x => x.Code == "available_ingredient_match");
        Assert.Equal(fish.VersionId, reason.RecipeVersionId);
        Assert.Equal("cá", reason.Detail);
        Assert.Equal("availableIngredients", reason.SourceField);
    }

    [Fact]
    public void Pantry_never_relaxes_allergy_or_vegetarian_constraints()
    {
        var unsafeMeal = Recipe("breakfast", "Tôm") with { Allergens = ["SHRIMP"] };
        var safe = Recipe("breakfast", "Gạo");
        var facts = new[] { new HealthFact("food_allergy", "SHRIMP", "Tôm", "present", "current", "allergies/0", "Tôm", "beneficiary") };
        var preferences = new MealPreferences("no_preference", [], []) { AvailableIngredients = ["tôm"] };
        var sets = MealConstraintPolicy.CandidateSets([unsafeMeal, safe, Recipe("lunch", "Gạo"), Recipe("dinner", "Gạo")], facts, [], preferences: preferences);
        Assert.All(sets, set => Assert.Equal(safe.VersionId, set[0].VersionId));
        Assert.Empty(MealConstraintPolicy.CandidateSets([unsafeMeal, safe, Recipe("lunch", "Gạo"), Recipe("dinner", "Gạo")],
            [], [], "vegetarian", preferences: preferences));
    }

    [Fact]
    public void Retry_identity_changes_with_pantry_but_ignores_order_case_and_unicode_representation()
    {
        var command = new RecommendMealsCommand(Guid.NewGuid(), new(3, Guid.NewGuid(), AvailableIngredients: ["bí đỏ", "CÁ"]));
        var hash = NutritionRequestFingerprint.For(command);
        Assert.Equal(hash, NutritionRequestFingerprint.For(command with { Input = command.Input with { AvailableIngredients = [" cá ", "bí đỏ", "CÁ"] } }));
        Assert.NotEqual(hash, NutritionRequestFingerprint.For(command with { Input = command.Input with { AvailableIngredients = ["trứng"] } }));
        Assert.NotEqual(hash, NutritionRequestFingerprint.For(command with { Input = command.Input with { AvailableIngredients = [] } }));
    }

    private static Recipe Recipe(string type, string ingredient) => new(Guid.NewGuid(), $"Món {ingredient}", type, 1,
        [new("FIXTURE", ingredient, 100, "g", "raw")], [], new() { ["energy_kcal"] = 100 }, ["Nấu chín"], ["Fixture"], true);

    [Fact]
    public void Approved_menu_name_with_separators_is_used_as_a_soft_preference()
    {
        var other = Recipe("breakfast", "Gạo");
        var liked = Recipe("breakfast", "Cá") with { Name = "Cá hấp, canh bí đỏ" };
        var ordered = MealConstraintPolicy.OrderForGoal([other, liked], "maintain", new("no_preference", ["Cá hấp canh bí đỏ"], []));
        Assert.Equal(liked.VersionId, ordered.First().VersionId);
    }

    [Fact]
    public void Historical_saved_plan_identity_survives_stale_status()
    {
        var resource = new NutritionResource(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 1, "saved", "{}", Guid.NewGuid(), "fixture", DateTimeOffset.UtcNow);
        var response = ResourceMapping.Map(resource, 2);
        Assert.Equal("stale", response.Status);
        Assert.True(response.Data.GetProperty("isSavedPlan").GetBoolean());
    }
}
