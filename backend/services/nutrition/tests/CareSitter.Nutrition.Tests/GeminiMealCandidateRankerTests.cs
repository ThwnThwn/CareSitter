using System.Net;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class GeminiMealCandidateRankerTests
{
    [Fact]
    public async Task Request_is_structured_and_response_preserves_supplied_catalog_ids()
    {
        var request = Request();
        var selected = request.CandidateSets[1];
        var output = new
        {
            selectedRecipeVersionIds = selected.Select(meal => meal.VersionId).ToArray(),
            explanations = selected.Select(meal => new
            {
                recipeVersionId = meal.VersionId,
                summary = "Phù hợp với mục tiêu và bằng chứng.",
                evidenceIds = new[] { "evidence-1" }
            }).ToArray()
        };
        var handler = new RecordingHandler(SuccessResponse(output));
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.BaseUrl) };
        using var guard = new MealRankingRuntimeGuard(options, TimeProvider.System);
        var ranker = new GeminiMealCandidateRanker(client, Options.Create(options), guard,
            NullLogger<GeminiMealCandidateRanker>.Instance);

        var result = await ranker.RankAsync(request, default);

        Assert.True(result.Available);
        Assert.Equal(selected.Select(meal => meal.VersionId), result.SelectedRecipeVersionIds);
        Assert.Equal("meal-ranker-v1", result.PromptVersion);
        Assert.Equal("/v1beta/models/gemini-3.5-flash-lite:generateContent", handler.RequestUri?.AbsolutePath);
        using var body = JsonDocument.Parse(handler.Body!);
        Assert.Equal("application/json", body.RootElement.GetProperty("generationConfig")
            .GetProperty("responseMimeType").GetString());
        Assert.Equal(JsonValueKind.Object, body.RootElement.GetProperty("generationConfig")
            .GetProperty("responseJsonSchema").ValueKind);
        var input = JsonDocument.Parse(body.RootElement.GetProperty("contents")[0]
            .GetProperty("parts")[0].GetProperty("text").GetString()!);
        Assert.Equal(2, input.RootElement.GetProperty("candidateSets").GetArrayLength());
        Assert.False(input.RootElement.GetProperty("healthFacts")[0].TryGetProperty("quote", out _));
    }

    [Fact]
    public async Task Invented_recipe_id_is_rejected_by_adapter()
    {
        var request = Request();
        var output = new
        {
            selectedRecipeVersionIds = new[] { Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid() },
            explanations = Array.Empty<object>()
        };
        var handler = new RecordingHandler(SuccessResponse(output));
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.BaseUrl) };
        using var guard = new MealRankingRuntimeGuard(options, TimeProvider.System);
        var ranker = new GeminiMealCandidateRanker(client, Options.Create(options), guard,
            NullLogger<GeminiMealCandidateRanker>.Instance);

        var result = await ranker.RankAsync(request, default);

        Assert.False(result.Available);
        Assert.Equal(["meal_ranking_invalid_output"], result.Warnings);
    }

    [Fact]
    public void Validator_requires_explicit_data_processing_approval()
    {
        var validator = new MealRankingOptionsValidator();

        Assert.True(validator.Validate(null, EnabledOptions()).Succeeded);
        Assert.True(validator.Validate(null, EnabledOptions() with { DataProcessingApproved = false }).Failed);
        Assert.True(validator.Validate(null, EnabledOptions() with { BaseUrl = HealthParserProviders.OpenAiBaseUrl }).Failed);
    }

    private static MealRankingOptions EnabledOptions() => new()
    {
        Enabled = true,
        Model = HealthParserProviders.GeminiModel,
        BaseUrl = HealthParserProviders.GeminiBaseUrl,
        ApiKey = "test-gemini-key-not-a-secret-1234567890",
        DataProcessingApproved = true,
        TimeoutSeconds = 5,
        MaxAttempts = 1,
        DailyBudget = 10
    };

    private static MealCandidateRankingRequest Request()
    {
        var breakfast1 = Recipe("breakfast", 100);
        var breakfast2 = Recipe("breakfast", 120);
        var lunch = Recipe("lunch", 200);
        var dinner = Recipe("dinner", 150);
        return new(7, [[breakfast1, lunch, dinner], [breakfast2, lunch, dinner]],
            [new("condition", "HYPERTENSION", "Tăng huyết áp", "present", "current", "note", "raw quote", "beneficiary")],
            [], [new("evidence-1", "Khuyến nghị", null, "10", "pdf-page:10", "Nguồn, trang 10", "Giảm muối")],
            "regular", "maintain");
    }

    private static Recipe Recipe(string mealType, decimal energy) => new(Guid.NewGuid(), $"Fixture {mealType}",
        mealType, 1, [new("RICE", "Gạo", 100, "g", "raw")], [],
        new() { ["energy_kcal"] = energy, ["sodium_mg"] = 10 }, ["Nấu chín"], ["Fixture"], true);

    private static HttpResponseMessage SuccessResponse(object result)
    {
        var body = JsonSerializer.Serialize(new
        {
            candidates = new[]
            {
                new
                {
                    finishReason = "STOP",
                    content = new { parts = new[] { new { text = JsonSerializer.Serialize(result, NutritionJson.Options) } } }
                }
            }
        }, NutritionJson.Options);
        return new(HttpStatusCode.OK) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
    }

    private sealed class RecordingHandler(params HttpResponseMessage[] responses) : HttpMessageHandler
    {
        public string? Body { get; private set; }
        public Uri? RequestUri { get; private set; }
        private int _requestCount;

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            RequestUri = request.RequestUri;
            Body = await request.Content!.ReadAsStringAsync(ct);
            return responses[_requestCount++];
        }
    }
}
