using System.Net;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class GeminiHealthDescriptionParserTests
{
    private const string Source = "Beni tăng huyết áp.";
    private static readonly NutritionConcept[] Concepts =
        [new("HYPERTENSION", "condition", ["tăng huyết áp"], 1)];

    [Fact]
    public async Task Request_uses_gemini_header_model_and_structured_output()
    {
        var handler = new RecordingHandler(SuccessResponse(Result()));
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.EffectiveBaseUrl) };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new GeminiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<GeminiHealthDescriptionParser>.Instance);

        var parsed = await parser.ParseAsync(Request(), default);

        Assert.Single(parsed.Facts);
        Assert.Equal("/v1beta/models/gemini-3.5-flash-lite:generateContent", handler.RequestUri?.AbsolutePath);
        Assert.Equal(options.ApiKey, handler.ApiKey);
        using var body = JsonDocument.Parse(Assert.IsType<string>(handler.Body));
        Assert.False(body.RootElement.GetProperty("store").GetBoolean());
        Assert.Equal("application/json", body.RootElement.GetProperty("generationConfig")
            .GetProperty("responseMimeType").GetString());
        Assert.Equal(JsonValueKind.Object, body.RootElement.GetProperty("generationConfig")
            .GetProperty("responseJsonSchema").ValueKind);
        var input = JsonDocument.Parse(body.RootElement.GetProperty("contents")[0]
            .GetProperty("parts")[0].GetProperty("text").GetString()!);
        Assert.Equal(HealthKnowledgeGraphRetriever.Strategy,
            input.RootElement.GetProperty("knowledgeGraph").GetProperty("retrievalStrategy").GetString());
    }

    [Fact]
    public async Task Authentication_failure_uses_stable_error_and_is_not_retried()
    {
        var handler = new RecordingHandler(new HttpResponseMessage(HttpStatusCode.Forbidden));
        var options = EnabledOptions() with { MaxAttempts = 2 };
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.EffectiveBaseUrl) };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new GeminiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<GeminiHealthDescriptionParser>.Instance);

        var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(Request(), default));

        Assert.Equal("nutrition.ai_authentication_failed", error.Code);
        Assert.False(error.Retryable);
        Assert.Equal(1, handler.RequestCount);
    }

    [Fact]
    public async Task Safety_block_is_reported_as_refusal()
    {
        var body = JsonSerializer.Serialize(new
        {
            promptFeedback = new { blockReason = "SAFETY" },
            candidates = Array.Empty<object>()
        }, NutritionJson.Options);
        var handler = new RecordingHandler(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        });
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.EffectiveBaseUrl) };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new GeminiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<GeminiHealthDescriptionParser>.Instance);

        var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(Request(), default));

        Assert.Equal("nutrition.ai_refused", error.Code);
        Assert.False(error.Retryable);
    }

    [Fact]
    public async Task Unique_exact_quote_repairs_model_offset_before_validation()
    {
        var expected = Result();
        var wrongOffset = expected with
        {
            Facts = [expected.Facts[0] with { StartOffset = 0, EndOffset = 3 }]
        };
        var handler = new RecordingHandler(SuccessResponse(wrongOffset));
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.EffectiveBaseUrl) };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new GeminiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<GeminiHealthDescriptionParser>.Instance);

        var parsed = await parser.ParseAsync(Request(), default);

        Assert.Equal(expected.Facts[0].StartOffset, parsed.Facts[0].StartOffset);
        Assert.Equal(expected.Facts[0].EndOffset, parsed.Facts[0].EndOffset);
        Assert.True(HealthParseResultValidator.TryValidate(Request(), parsed, out _));
    }

    [Fact]
    public async Task Wrong_offset_with_repeated_quote_is_rejected_as_ambiguous()
    {
        const string repeated = "tăng huyết áp; tăng huyết áp";
        var sources = new Dictionary<string, string> { ["note"] = repeated };
        var request = new HealthParseRequest(1, 7, sources, Concepts,
            HealthKnowledgeGraphRetriever.Retrieve(7, sources, Concepts, []));
        var output = new HealthParseResult(1, 7,
            [new("condition", "HYPERTENSION", "Tăng huyết áp", "present", "current", "note",
                "tăng huyết áp", "beneficiary", 1, 2)], [], []);
        var handler = new RecordingHandler(SuccessResponse(output));
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri(options.EffectiveBaseUrl) };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new GeminiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<GeminiHealthDescriptionParser>.Instance);

        var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(request, default));

        Assert.Equal("nutrition.ai_invalid_output", error.Code);
    }

    [Fact]
    public void Validator_accepts_gemini_and_rejects_cross_provider_configuration()
    {
        var validator = new HealthParserOptionsValidator();

        var valid = validator.Validate(null, EnabledOptions());
        var openAiUrl = validator.Validate(null, EnabledOptions() with
        {
            BaseUrl = HealthParserProviders.OpenAiBaseUrl
        });
        var openAiModel = validator.Validate(null, EnabledOptions() with
        {
            Model = HealthParserProviders.OpenAiModel
        });

        Assert.True(valid.Succeeded);
        Assert.True(openAiUrl.Failed);
        Assert.True(openAiModel.Failed);
    }

    [Fact]
    public void Validator_accepts_flash_lite_and_existing_flash_model()
    {
        var validator = new HealthParserOptionsValidator();
        var flashLite = EnabledOptions() with { Model = "gemini-3.5-flash-lite" };
        var flash = EnabledOptions() with { Model = "gemini-3.8-flash" };

        Assert.True(validator.Validate(null, flashLite).Succeeded);
        Assert.True(validator.Validate(null, flash).Succeeded);
    }

    private static HealthParserOptions EnabledOptions() => new()
    {
        Enabled = true,
        Provider = HealthParserProviders.Gemini,
        Model = HealthParserProviders.GeminiModel,
        BaseUrl = HealthParserProviders.GeminiBaseUrl,
        ApiKey = "test-gemini-key-not-a-secret-1234567890",
        DataProcessingApproved = true,
        TimeoutSeconds = 5,
        MaxAttempts = 1,
        DailyBudget = 10
    };

    private static HealthParseRequest Request()
    {
        var sources = new Dictionary<string, string> { ["note"] = Source };
        return new(1, 7, sources, Concepts, HealthKnowledgeGraphRetriever.Retrieve(7, sources, Concepts, []));
    }

    private static HealthParseResult Result()
    {
        var start = Source.IndexOf("tăng huyết áp", StringComparison.Ordinal);
        return new(1, 7,
            [new("condition", "HYPERTENSION", "Tăng huyết áp", "present", "current", "note",
                "tăng huyết áp", "beneficiary", start, start + "tăng huyết áp".Length)], [], []);
    }

    private static HttpResponseMessage SuccessResponse(HealthParseResult result)
    {
        var responseBody = JsonSerializer.Serialize(new
        {
            candidates = new[]
            {
                new
                {
                    finishReason = "STOP",
                    content = new { parts = new[] { new { text = NutritionJson.Write(result) } } }
                }
            },
            usageMetadata = new { promptTokenCount = 20, candidatesTokenCount = 10 }
        }, NutritionJson.Options);
        return new(HttpStatusCode.OK)
        {
            Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
        };
    }

    private sealed class RecordingHandler(params HttpResponseMessage[] responses) : HttpMessageHandler
    {
        public string? Body { get; private set; }
        public string? ApiKey { get; private set; }
        public Uri? RequestUri { get; private set; }
        public int RequestCount { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            RequestCount++;
            RequestUri = request.RequestUri;
            Body = await request.Content!.ReadAsStringAsync(ct);
            ApiKey = request.Headers.GetValues("x-goog-api-key").Single();
            return responses[RequestCount - 1];
        }
    }
}
