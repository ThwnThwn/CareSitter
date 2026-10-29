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
