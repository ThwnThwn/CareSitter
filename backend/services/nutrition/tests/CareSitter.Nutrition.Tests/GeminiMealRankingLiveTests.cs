using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class GeminiMealRankingLiveTests
{
    [SyntheticGeminiFact]
    public async Task Synthetic_candidates_can_be_ranked_by_the_real_provider()
    {
        var options = new MealRankingOptions
        {
            Enabled = true,
            DataProcessingApproved = true,
            ApiKey = Environment.GetEnvironmentVariable("CARESITTER_SYNTHETIC_GEMINI_KEY")!,
            Model = HealthParserProviders.GeminiModel,
            BaseUrl = HealthParserProviders.GeminiBaseUrl,
            TimeoutSeconds = 25,
            MaxAttempts = 1,
            DailyBudget = 1
        };
        var breakfast1 = Recipe("breakfast", "Món thử A", 200);
        var breakfast2 = Recipe("breakfast", "Món thử B", 220);
        var lunch = Recipe("lunch", "Món thử C", 300);
        var dinner = Recipe("dinner", "Món thử D", 280);
        var candidates = new[] { new[] { breakfast1, lunch, dinner }, new[] { breakfast2, lunch, dinner } };
        var request = new MealRecommendationRequest(1,
            [breakfast1, breakfast2, lunch, dinner], [], [], "regular", "maintain");
        using var client = new HttpClient { BaseAddress = new Uri(options.BaseUrl) };
        using var guard = new MealRankingRuntimeGuard(options, TimeProvider.System);
        var ranker = new GeminiMealCandidateRanker(client, Options.Create(options), guard,
            NullLogger<GeminiMealCandidateRanker>.Instance);

        var engine = new MealRecommendationEngine(new SyntheticKnowledge(), ranker);
        var result = await engine.RecommendAsync(request, CancellationToken.None);

        Assert.True(result.Trace.UsedAi, string.Join(", ", result.Trace.Warnings));
        Assert.Equal("graph_grounded_ai_ranked", result.Trace.Strategy);
        Assert.Contains(candidates, set => set.Select(meal => meal.VersionId)
            .SequenceEqual(result.Meals!.Select(meal => meal.VersionId)));
        Assert.True(MealConstraintPolicy.Matches(result.Meals!, [], []));
        Assert.Equal(3, result.Trace.Explanations.Length);

        var fallback = await new MealRecommendationEngine(new SyntheticKnowledge(),
            new UnavailableMealCandidateRanker()).RecommendAsync(request, CancellationToken.None);
        Assert.False(fallback.Trace.UsedAi);
        Assert.Equal("graph_grounded_rule", fallback.Trace.Strategy);
        Assert.True(MealConstraintPolicy.Matches(fallback.Meals!, [], []));
    }

    private static Recipe Recipe(string type, string name, decimal energy) => new(
        Guid.NewGuid(), name, type, 1, [new("TEST", "Nguyên liệu thử", 100, "g", "raw")], [],
        new() { ["energy_kcal"] = energy }, ["Nấu chín"], ["synthetic-1"], true);

    private sealed class SyntheticKnowledge : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            Task.FromResult(new MealKnowledgeResult(true, "synthetic-v1", "synthetic",
                [new("synthetic-1", "Dữ liệu thử nghiệm tổng hợp", null, "1", "fixture", "Nguồn thử", "Không có nội dung sách")], []));
    }
}

public sealed class SyntheticGeminiFactAttribute : FactAttribute
{
    public SyntheticGeminiFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("CARESITTER_SYNTHETIC_GEMINI_TEST") != "1" ||
            string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("CARESITTER_SYNTHETIC_GEMINI_KEY")))
            Skip = "Chỉ chạy thủ công với khóa và dữ liệu tổng hợp.";
    }
}
