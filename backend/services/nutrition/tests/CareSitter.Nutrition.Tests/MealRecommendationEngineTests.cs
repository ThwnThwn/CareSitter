using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class MealRecommendationEngineTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Recent_saved_meals_are_avoided_by_ai_and_fallback(bool useAi)
    {
        var old = new[] { Recipe("breakfast", 100), Recipe("lunch", 200), Recipe("dinner", 150) };
        var fresh = old.Select(meal => meal with { VersionId = Guid.NewGuid(), Name = "New " + meal.Name }).ToArray();
        IMealKnowledgeRetriever knowledge = useAi ? new StaticKnowledgeRetriever() : new UnavailableMealKnowledgeRetriever();
        var engine = new MealRecommendationEngine(knowledge, new SelectingRanker(request => request.CandidateSets[0]));

        var result = await engine.RecommendAsync(new(7, [.. old, .. fresh], [], [], "regular", "maintain", old), CancellationToken.None);

        Assert.Equal(fresh.Select(meal => meal.VersionId), result.Meals!.Select(meal => meal.VersionId));
        Assert.Equal(useAi, result.Trace.UsedAi);
    }

    [Fact]
    public void Variety_searches_beyond_original_shortlist_and_recognizes_demo_names()
    {
        var old = new[] { Recipe("breakfast", 100), Recipe("lunch", 200), Recipe("dinner", 150) };
        var fresh = old.Select(meal => meal with { VersionId = Guid.NewGuid(), Name = "New " + meal.Name }).ToArray();
        var saved = old.Select(meal => meal with { VersionId = Guid.NewGuid(), Name = "[DEMO] " + meal.Name }).ToArray();
        var sets = MealConstraintPolicy.CandidateSets([.. old, .. fresh], [], [], maximum: 1, recentMeals: saved);
        Assert.Equal(fresh.Select(meal => meal.VersionId), Assert.Single(sets).Select(meal => meal.VersionId));
    }

    [Fact]
    public void Variety_keeps_safe_repeated_meals_when_alternative_contains_allergen()
    {
        var old = new[] { Recipe("breakfast", 100), Recipe("lunch", 200), Recipe("dinner", 150) };
        var unsafeMeal = Recipe("breakfast", 100) with { Name = "New breakfast", Allergens = ["SHRIMP"] };
        var facts = new[] { new HealthFact("food_allergy", "SHRIMP", "Tôm", "present", "current", "allergies/0", "Tôm", "beneficiary") };
        var sets = MealConstraintPolicy.CandidateSets([.. old, unsafeMeal], facts, [], recentMeals: old);
        Assert.Equal(old.Select(meal => meal.VersionId), Assert.Single(sets).Select(meal => meal.VersionId));
    }

    [Fact]
    public void Yesterday_repeats_are_avoided_before_older_repeats()
    {
        Recipe[] Day(int index) => [Recipe("breakfast", 100) with { Name = $"B{index}" },
            Recipe("lunch", 200) with { Name = $"L{index}" }, Recipe("dinner", 150) with { Name = $"D{index}" }];
        var yesterday = Day(0);
        var twoDaysAgo = Day(1);

        // Every combination repeats three recent dishes; only the yesterday-free one may win.
        var selected = Assert.Single(MealConstraintPolicy.CandidateSets([.. yesterday, .. twoDaysAgo], [], [],
            maximum: 1, recentMeals: [.. yesterday, .. twoDaysAgo], yesterdayMeals: yesterday));

        Assert.Equal(twoDaysAgo.Select(meal => meal.VersionId), selected.Select(meal => meal.VersionId));
    }

    [Fact]
    public void Seeded_variety_is_stable_within_a_day_and_changes_across_days()
    {
        var recipes = new[] { "breakfast", "lunch", "dinner" }
            .SelectMany(type => Enumerable.Range(0, 4).Select(index => Recipe(type, 200) with { Name = $"{type} {index}" }))
            .ToArray();
        Recipe[] Pick(string seed) => Assert.Single(MealConstraintPolicy.CandidateSets(recipes, [], [],
            maximum: 1, varietySeed: seed));
        string Ids(Recipe[] menu) => string.Join("|", menu.Select(meal => meal.VersionId));

        Assert.Equal(Ids(Pick("owner|2026-11-10|7")), Ids(Pick("owner|2026-11-10|7")));
        var menus = Enumerable.Range(10, 10).Select(day => Ids(Pick($"owner|2026-11-{day}|7"))).ToHashSet();
        Assert.True(menus.Count > 1, "A seeded shuffle must not return the same menu every day.");
    }

    [Fact]
    public void A_week_of_seeded_menus_never_repeats_a_dish_from_the_day_before()
    {
        var recipes = new[] { "breakfast", "lunch", "dinner" }
            .SelectMany(type => Enumerable.Range(0, 3).Select(index => Recipe(type, 200 + index) with { Name = $"{type} {index}" }))
            .ToArray();
        var history = new List<Recipe[]>();
        for (var day = 1; day <= 14; day++)
        {
            var yesterday = history.LastOrDefault() ?? [];
            var selected = Assert.Single(MealConstraintPolicy.CandidateSets(recipes, [], [], maximum: 1,
                recentMeals: history.TakeLast(3).SelectMany(menu => menu).ToArray(),
                previousMenus: history.TakeLast(6).Reverse().ToArray(), yesterdayMeals: yesterday,
                varietySeed: $"owner|2026-11-{day:00}|7"));
            Assert.DoesNotContain(selected, meal => yesterday.Any(previous => previous.VersionId == meal.VersionId));
            history.Add(selected);
        }
    }

    [Fact]
    public void Seeded_variety_never_picks_a_menu_outside_the_energy_band()
    {
        var recipes = new[]
        {
            Recipe("breakfast", 300), Recipe("breakfast", 310), Recipe("breakfast", 900),
            Recipe("lunch", 500), Recipe("dinner", 500)
        };
        foreach (var goal in new[] { "lose", "maintain", "gain" })
        {
            var best = Assert.Single(MealConstraintPolicy.CandidateSets(recipes, [], [], nutritionGoal: goal, maximum: 1));
            var target = best.Sum(meal => meal.Nutrients["energy_kcal"]!.Value);
            for (var day = 1; day <= 20; day++)
            {
                var selected = Assert.Single(MealConstraintPolicy.CandidateSets(recipes, [], [], nutritionGoal: goal,
                    maximum: 1, varietySeed: $"owner|2026-11-{day:00}|7"));
                var energy = selected.Sum(meal => meal.Nutrients["energy_kcal"]!.Value);
                Assert.True(Math.Abs(energy - target) <= target * MealConstraintPolicy.VarietyEnergyBand,
                    $"{goal}: {energy} kcal is outside the band around {target} kcal.");
            }
        }
    }

    [Fact]
    public void A_new_day_uses_a_different_complete_menu_when_safe_choices_exist()
    {
        var breakfasts = Enumerable.Range(0, 2).Select(index => Recipe("breakfast", 100) with { Name = $"Breakfast {index}" }).ToArray();
        var lunches = Enumerable.Range(0, 2).Select(index => Recipe("lunch", 200) with { Name = $"Lunch {index}" }).ToArray();
        var dinners = Enumerable.Range(0, 2).Select(index => Recipe("dinner", 150) with { Name = $"Dinner {index}" }).ToArray();
        var recipes = breakfasts.Concat(lunches).Concat(dinners).ToArray();
        var previous = new List<Recipe[]>();
        for (var day = 0; day < 7; day++)
        {
            var selected = Assert.Single(MealConstraintPolicy.CandidateSets(recipes, [], [],
                maximum: 1, previousMenus: previous));
            Assert.DoesNotContain(previous, menu => menu.Select(meal => meal.VersionId)
                .SequenceEqual(selected.Select(meal => meal.VersionId)));
            previous.Add(selected);
        }
    }

    [Fact]
    public async Task Baseline_returns_safe_catalog_ids_and_explicit_non_ai_trace()
    {
        var recipes = new[]
        {
            Recipe("breakfast", 100), Recipe("lunch", 200), Recipe("dinner", 150)
        };
        var engine = new MealRecommendationEngine(new UnavailableMealKnowledgeRetriever(),
            new UnavailableMealCandidateRanker());

        var result = await engine.RecommendAsync(new MealRecommendationRequest(
            7, recipes, [], [], "regular", "maintain"), CancellationToken.None);

        Assert.NotNull(result.Meals);
        Assert.Equal(recipes.Select(recipe => recipe.VersionId), result.Meals!.Select(recipe => recipe.VersionId));
        Assert.Equal("rule_baseline", result.Trace.Strategy);
        Assert.False(result.Trace.UsedAi);
        Assert.Null(result.Trace.Model);
        Assert.Null(result.Trace.PromptVersion);
        Assert.Empty(result.Trace.Evidence);
        Assert.Empty(result.Trace.Explanations);
        Assert.Equal(["grounding_not_configured"], result.Trace.Warnings);
        Assert.True(MealConstraintPolicy.Matches(result.Meals, [], []));
    }

    [Fact]
    public async Task Baseline_does_not_relax_constraints_when_no_safe_combination_exists()
    {
        var breakfast = Recipe("breakfast", 100) with { Allergens = ["SHRIMP"] };
        var facts = new[]
        {
            new HealthFact("food_allergy", "SHRIMP", "Tôm", "present", "current", "allergies/0", "Tôm", "beneficiary")
        };
        var engine = new MealRecommendationEngine(new UnavailableMealKnowledgeRetriever(),
            new UnavailableMealCandidateRanker());

        var result = await engine.RecommendAsync(new MealRecommendationRequest(7,
            [breakfast, Recipe("lunch", 200), Recipe("dinner", 150)], facts, [],
            "regular", "maintain"), CancellationToken.None);

        Assert.Null(result.Meals);
        Assert.Equal(["constraints_not_matched"], result.Trace.Warnings);
        Assert.False(result.Trace.UsedAi);
    }

    [Fact]
    public void Legacy_payload_without_recommendation_trace_remains_readable()
    {
        var assessment = Guid.NewGuid();
        var payload = $$"""
            {
              "schemaVersion": 1,
              "assessmentId": "{{assessment}}",
              "plannedDate": "2026-10-27",
              "meals": [],
              "appliedRules": [],
              "decision": {
                "state": "no_match",
                "reasonCodes": ["constraints_not_matched"],
                "missingFields": [],
                "conflicts": [],
                "requiredGuidance": [],
                "allowedActions": ["edit_health"]
              },
              "catalogRevision": 7
            }
            """;

        var parsed = NutritionJson.Read<MealPayload>(payload);

        Assert.Equal(assessment, parsed.AssessmentId);
        Assert.Null(parsed.RecommendationTrace);
    }

    [Fact]
    public async Task Cancellation_is_observed_before_selection()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var engine = new MealRecommendationEngine(new UnavailableMealKnowledgeRetriever(),
            new UnavailableMealCandidateRanker());

        await Assert.ThrowsAsync<OperationCanceledException>(() => engine.RecommendAsync(
            new MealRecommendationRequest(7, [], [], [], "regular", "maintain"), cancellation.Token));
    }

    [Fact]
    public async Task Grounded_ranker_can_select_only_a_complete_safe_candidate_set()
    {
        var recipes = new[]
        {
            Recipe("breakfast", 100), Recipe("breakfast", 110),
            Recipe("lunch", 200), Recipe("dinner", 150)
        };
        var ranker = new SelectingRanker(request => request.CandidateSets[^1]);
        var engine = new MealRecommendationEngine(new StaticKnowledgeRetriever(), ranker);

        var result = await engine.RecommendAsync(new MealRecommendationRequest(
            7, recipes, [], [], "regular", "maintain"), CancellationToken.None);

        Assert.NotNull(result.Meals);
        Assert.Equal(ranker.SelectedIds, result.Meals!.Select(meal => meal.VersionId));
        Assert.Equal("graph_grounded_ai_ranked", result.Trace.Strategy);
        Assert.True(result.Trace.UsedAi);
        Assert.Equal("gemini-fixture", result.Trace.Model);
        Assert.Single(result.Trace.Evidence);
        Assert.Equal(3, result.Trace.Explanations.Length);
        Assert.True(MealConstraintPolicy.Matches(result.Meals, [], []));
    }

    [Fact]
    public async Task Hallucinated_ranker_ids_are_rejected_and_safe_baseline_is_returned()
    {
        var recipes = new[]
        {
            Recipe("breakfast", 100), Recipe("breakfast", 110),
            Recipe("lunch", 200), Recipe("dinner", 150)
        };
        var engine = new MealRecommendationEngine(new StaticKnowledgeRetriever(), new HallucinatingRanker());

        var result = await engine.RecommendAsync(new MealRecommendationRequest(
            7, recipes, [], [], "regular", "maintain"), CancellationToken.None);

        Assert.NotNull(result.Meals);
        Assert.False(result.Trace.UsedAi);
        Assert.Equal("graph_grounded_rule", result.Trace.Strategy);
        Assert.Contains("meal_ranking_rejected", result.Trace.Warnings);
        Assert.All(result.Meals!, meal => Assert.Contains(meal.VersionId, recipes.Select(recipe => recipe.VersionId)));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Demo_disclosure_is_preserved_for_ai_and_rule_fallback(bool useAi)
    {
        var recipes = new[] { Recipe("breakfast", 100), Recipe("lunch", 200), Recipe("dinner", 150) };
        var knowledge = new StaticKnowledgeRetriever(MealGroundingOptions.OwnerAuthorizedGraphDemoMode,
            ["academic_demo_owner_authorized", "independent_clinical_review_not_claimed"]);
        IMealCandidateRanker ranker = useAi ? new SelectingRanker(request => request.CandidateSets[0]) :
            new UnavailableMealCandidateRanker();

        var result = await new MealRecommendationEngine(knowledge, ranker).RecommendAsync(
            new(7, recipes, [], [], "regular", "maintain"), CancellationToken.None);

        Assert.Equal(useAi, result.Trace.UsedAi);
        Assert.Equal(useAi ? "graph_grounded_ai_ranked" : "graph_grounded_rule", result.Trace.Strategy);
        Assert.Equal(MealGroundingOptions.OwnerAuthorizedGraphDemoMode, result.Trace.GroundingStrategy);
        Assert.Contains("independent_clinical_review_not_claimed", result.Trace.Warnings);
        Assert.True(MealConstraintPolicy.Matches(result.Meals!, [], []));
    }

    private static Recipe Recipe(string mealType, decimal energy) => new(Guid.NewGuid(), $"Fixture {mealType}",
        mealType, 1, [new("RICE", "Gạo", 100, "g", "raw")], [],
        new() { ["energy_kcal"] = energy, ["sodium_mg"] = 10 }, ["Nấu chín"], ["Fixture"], true);

    private sealed class StaticKnowledgeRetriever(string strategy = "graph", string[]? warnings = null) : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            Task.FromResult(new MealKnowledgeResult(true, "fixture-revision", strategy,
                [new("evidence-1", "Fixture", null, "1", "pdf-page:1", "Fixture, trang 1", "Nội dung")], warnings ?? []));
    }

    private sealed class SelectingRanker(Func<MealCandidateRankingRequest, Recipe[]> select) : IMealCandidateRanker
    {
        public Guid[] SelectedIds { get; private set; } = [];

        public Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request,
            CancellationToken ct)
        {
            SelectedIds = select(request).Select(meal => meal.VersionId).ToArray();
            var explanations = SelectedIds.Select(id =>
                new MealRecommendationExplanation(id, "Phù hợp fixture", ["evidence-1"])).ToArray();
            return Task.FromResult(new MealCandidateRankingResult(true, SelectedIds,
                "gemini-fixture", "meal-ranker-v1", explanations, []));
        }
    }

    private sealed class HallucinatingRanker : IMealCandidateRanker
    {
        public Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request,
            CancellationToken ct) => Task.FromResult(new MealCandidateRankingResult(true,
            [Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid()], "gemini-fixture", "meal-ranker-v1", [], []));
    }
}
