using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class OpenAiHealthDescriptionParserTests
{
    private const string Source = "Beni tăng huyết áp.";
    private static readonly NutritionConcept[] Concepts =
        [new("HYPERTENSION", "condition", ["tăng huyết áp"], 1)];

    [Fact]
    public async Task Request_uses_versioned_local_graph_and_disables_storage_and_tools()
    {
        var start = Source.IndexOf("tăng huyết áp", StringComparison.Ordinal);
        var result = new HealthParseResult(1, 7,
            [new("condition", "HYPERTENSION", "Tăng huyết áp", "present", "current", "note",
                "tăng huyết áp", "beneficiary", start, start + "tăng huyết áp".Length)], [], []);
        var responseBody = JsonSerializer.Serialize(new
        {
            status = "completed",
            output = new[] { new { content = new[] { new { type = "output_text", text = NutritionJson.Write(result) } } } },
            usage = new { input_tokens = 20, output_tokens = 10 }
        }, NutritionJson.Options);
        var handler = new RecordingHandler(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
        });
        var options = EnabledOptions();
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://api.openai.com/v1/") };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new OpenAiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<OpenAiHealthDescriptionParser>.Instance);
        var sources = new Dictionary<string, string> { ["note"] = Source };
        var graph = HealthKnowledgeGraphRetriever.Retrieve(7, sources, Concepts, []);

        var parsed = await parser.ParseAsync(new(1, 7, sources, Concepts, graph), default);

        Assert.Single(parsed.Facts);
        using var request = JsonDocument.Parse(Assert.IsType<string>(handler.Body));
        Assert.False(request.RootElement.GetProperty("store").GetBoolean());
        Assert.Empty(request.RootElement.GetProperty("tools").EnumerateArray());
        var input = JsonDocument.Parse(request.RootElement.GetProperty("input").GetString()!);
        Assert.Equal(HealthKnowledgeGraphRetriever.Strategy,
            input.RootElement.GetProperty("knowledgeGraph").GetProperty("retrievalStrategy").GetString());
        Assert.False(input.RootElement.TryGetProperty("concepts", out _));
    }

    [Fact]
    public async Task Transient_retry_reuses_the_same_idempotency_key()
    {
        var throttled = new HttpResponseMessage(HttpStatusCode.TooManyRequests);
        throttled.Headers.RetryAfter = new RetryConditionHeaderValue(TimeSpan.Zero);
        var handler = new RecordingHandler(throttled, SuccessResponse(new HealthParseResult(1, 7, [], [], ["note"])));
        var options = EnabledOptions() with { MaxAttempts = 2 };
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://api.openai.com/v1/") };
        using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        var parser = new OpenAiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<OpenAiHealthDescriptionParser>.Instance);
        var sources = new Dictionary<string, string> { ["note"] = "Beni thích nghe nhạc." };
        var graph = HealthKnowledgeGraphRetriever.Retrieve(7, sources, Concepts, []);

        var parsed = await parser.ParseAsync(new(1, 7, sources, Concepts, graph), default);

        Assert.Empty(parsed.Facts);
        Assert.Equal(2, handler.IdempotencyKeys.Count);
        Assert.Equal(handler.IdempotencyKeys[0], handler.IdempotencyKeys[1]);
    }

    [Fact]
    public void Enabled_configuration_requires_explicit_data_processing_approval_and_server_key()
    {
        var validator = new HealthParserOptionsValidator();

        var missingApproval = validator.Validate(null, EnabledOptions() with { DataProcessingApproved = false });
        var missingKey = validator.Validate(null, EnabledOptions() with { ApiKey = "" });
        var disabled = validator.Validate(null, new HealthParserOptions());

        Assert.True(missingApproval.Failed);
        Assert.True(missingKey.Failed);
        Assert.True(disabled.Succeeded);
    }

    [Fact]
    public void Redaction_preserves_offsets_while_masking_identifiers()
    {
        const string raw = "Tên là Nguyễn Văn An, email an@example.com, SĐT 0912345678; bị tăng huyết áp.";

        var safe = HealthTextRedactor.Redact(raw);

        Assert.Equal(raw.Length, safe.Length);
        Assert.DoesNotContain("Nguyễn Văn An", safe, StringComparison.Ordinal);
        Assert.DoesNotContain("an@example.com", safe, StringComparison.Ordinal);
        Assert.DoesNotContain("0912345678", safe, StringComparison.Ordinal);
        Assert.Equal(raw.IndexOf("tăng huyết áp", StringComparison.Ordinal),
            safe.IndexOf("tăng huyết áp", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Malformed_structured_output_is_rejected_with_stable_error()
    {
        var body = JsonSerializer.Serialize(new
        {
            status = "completed",
            output = new[] { new { content = new[] { new { type = "output_text", text = "{" } } } }
        }, NutritionJson.Options);
        var parser = Parser(new RecordingHandler(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        }), EnabledOptions(), out var disposable);
        using (disposable)
        {
            var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(Request(), default));
            Assert.Equal("nutrition.ai_invalid_output", error.Code);
            Assert.False(error.Retryable);
        }
    }

    [Fact]
    public async Task Provider_authentication_failure_is_reported_precisely_and_not_retried()
    {
        var handler = new RecordingHandler(new HttpResponseMessage(HttpStatusCode.Forbidden));
        var parser = Parser(handler, EnabledOptions() with { MaxAttempts = 2 }, out var disposable);
        using (disposable)
        {
            var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(Request(), default));
            Assert.Equal("nutrition.ai_authentication_failed", error.Code);
            Assert.False(error.Retryable);
            Assert.Single(handler.IdempotencyKeys);
        }
    }

    [Theory]
    [InlineData(HttpStatusCode.BadRequest)]
    [InlineData(HttpStatusCode.NotFound)]
    public async Task Provider_configuration_failure_is_reported_precisely(HttpStatusCode statusCode)
    {
        var parser = Parser(new RecordingHandler(new HttpResponseMessage(statusCode)), EnabledOptions(),
            out var disposable);
        using (disposable)
        {
            var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(Request(), default));
            Assert.Equal("nutrition.ai_configuration_invalid", error.Code);
            Assert.False(error.Retryable);
        }
    }

    [Fact]
    public async Task Disabled_parser_is_reported_as_not_configured()
    {
        var parser = Parser(new RecordingHandler(), new HealthParserOptions(), out var disposable);
        using (disposable)
        {
            var error = await Assert.ThrowsAsync<HealthParserException>(() => parser.ParseAsync(Request(), default));
            Assert.Equal("nutrition.ai_not_configured", error.Code);
            Assert.False(error.Retryable);
        }
    }

    [Fact]
    public async Task Provider_call_obeys_total_timeout()
    {
        var parser = Parser(new WaitingHandler(), EnabledOptions() with { TimeoutSeconds = 1 }, out var disposable);
        using (disposable)
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => parser.ParseAsync(Request(), default));
    }

    private static HealthParserOptions EnabledOptions() => new()
    {
        Enabled = true,
        DataProcessingApproved = true,
        ApiKey = "test-key-not-a-secret-1234567890",
        TimeoutSeconds = 5,
        MaxAttempts = 1,
        DailyBudget = 10
    };

    private static HealthParseRequest Request()
    {
        var sources = new Dictionary<string, string> { ["note"] = Source };
        return new(1, 7, sources, Concepts, HealthKnowledgeGraphRetriever.Retrieve(7, sources, Concepts, []));
    }

    private static OpenAiHealthDescriptionParser Parser(HttpMessageHandler handler, HealthParserOptions options,
        out IDisposable disposable)
    {
        var client = new HttpClient(handler) { BaseAddress = new Uri("https://api.openai.com/v1/") };
        var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
        disposable = new CompositeDisposable(client, guard);
        return new OpenAiHealthDescriptionParser(client, Options.Create(options), guard,
            NullLogger<OpenAiHealthDescriptionParser>.Instance);
    }

    private static HttpResponseMessage SuccessResponse(HealthParseResult result)
    {
        var responseBody = JsonSerializer.Serialize(new
        {
            status = "completed",
            output = new[]
            {
                new { content = new[] { new { type = "output_text", text = NutritionJson.Write(result) } } }
            }
        }, NutritionJson.Options);
        return new(HttpStatusCode.OK) { Content = new StringContent(responseBody, Encoding.UTF8, "application/json") };
    }

    private sealed class RecordingHandler(params HttpResponseMessage[] responses) : HttpMessageHandler
    {
        public string? Body { get; private set; }
        public List<string> IdempotencyKeys { get; } = [];
        private int _index;

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Body = await request.Content!.ReadAsStringAsync(ct);
            IdempotencyKeys.Add(request.Headers.GetValues("Idempotency-Key").Single());
            return responses[_index++];
        }
    }

    private sealed class WaitingHandler : HttpMessageHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            await Task.Delay(TimeSpan.FromMinutes(1), ct);
            return new HttpResponseMessage(HttpStatusCode.OK);
        }
    }

    private sealed class CompositeDisposable(params IDisposable[] values) : IDisposable
    {
        public void Dispose()
        {
            foreach (var value in values) value.Dispose();
        }
    }
}
