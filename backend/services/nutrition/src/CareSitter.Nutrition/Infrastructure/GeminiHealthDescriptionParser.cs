using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class GeminiHealthDescriptionParser(HttpClient http, IOptions<HealthParserOptions> configured,
    HealthParserRuntimeGuard guard, ILogger<GeminiHealthDescriptionParser> logger) : IHealthDescriptionParser
{
    private readonly HealthParserOptions _options = configured.Value;
    public bool IsReady => _options.Enabled;
    public string PromptVersion => OpenAiHealthParserContract.PromptVersion;

    public async Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct)
    {
        if (!_options.Enabled) throw new HealthParserException("nutrition.ai_not_configured", false);
        if (request.Sources.Values.Sum(value => value.Length) > _options.MaxInputCharacters)
            throw new HealthParserException("nutrition.ai_input_too_large", false);
        if (!HealthKnowledgeGraphRetriever.IsValid(request.Graph, request.DictionaryRevision))
            throw new HealthParserException("nutrition.ai_invalid_output", false);
        using var concurrency = await guard.EnterAsync(ct);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));
        var redacted = HealthTextRedactor.Redact(request.Sources);
        var requestBody = BuildRequest(request, redacted);
        var stopwatch = Stopwatch.StartNew();
        var inputTokens = 0L;
        var outputTokens = 0L;
        for (var attempt = 1; attempt <= _options.MaxAttempts; attempt++)
        {
            if (!guard.TryConsumeAttempt()) throw new HealthParserException("nutrition.ai_budget_exhausted", false);
            try
            {
                using var message = new HttpRequestMessage(HttpMethod.Post,
                    $"models/{Uri.EscapeDataString(_options.EffectiveModel)}:generateContent")
                {
                    Content = new ByteArrayContent(requestBody)
                };
                message.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                message.Headers.Add("x-goog-api-key", _options.ReadApiKey());
                message.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                using var response = await http.SendAsync(message, HttpCompletionOption.ResponseHeadersRead,
                    timeout.Token);
                if (Transient(response.StatusCode) && attempt < _options.MaxAttempts)
                {
                    await DelayForRetryAsync(response.Headers.RetryAfter, timeout.Token);
                    continue;
                }
                if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
                {
                    logger.LogWarning(
                        "Nutrition AI provider rejected its credential: Provider={Provider}, StatusCode={StatusCode}, ErrorCode={ErrorCode}.",
                        HealthParserProviders.Gemini, (int)response.StatusCode, "nutrition.ai_authentication_failed");
                    throw new HealthParserException("nutrition.ai_authentication_failed", false);
                }
                if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.NotFound)
                {
                    logger.LogWarning(
                        "Nutrition AI provider rejected its request configuration: Provider={Provider}, StatusCode={StatusCode}, ErrorCode={ErrorCode}.",
                        HealthParserProviders.Gemini, (int)response.StatusCode, "nutrition.ai_configuration_invalid");
                    throw new HealthParserException("nutrition.ai_configuration_invalid", false);
                }
                if (response.StatusCode is HttpStatusCode.TooManyRequests)
                    throw new HealthParserException("nutrition.ai_rate_limited", true);
                if (!response.IsSuccessStatusCode)
                    throw new HealthParserException("nutrition.ai_unavailable", Transient(response.StatusCode));
                var body = await ReadLimitedAsync(response.Content, _options.MaxResponseBytes, timeout.Token);
                var parsed = ParseResponse(body, request, redacted, out var usage);
                inputTokens += usage.InputTokens;
                outputTokens += usage.OutputTokens;
                logger.LogInformation(
                    "Nutrition GraphRAG parser completed: Provider={Provider}, Model={Model}, Prompt={Prompt}, Schema={Schema}, Dictionary={Dictionary}, GraphSchema={GraphSchema}, GraphNodes={GraphNodes}, GraphEdges={GraphEdges}, Retrieval={Retrieval}, Attempts={Attempts}, LatencyMs={LatencyMs}, InputTokens={InputTokens}, OutputTokens={OutputTokens}.",
                    HealthParserProviders.Gemini, _options.EffectiveModel, OpenAiHealthParserContract.PromptVersion,
                    request.SchemaVersion, request.DictionaryRevision, request.Graph.SchemaVersion,
                    request.Graph.Nodes.Length, request.Graph.Edges.Length, request.Graph.RetrievalStrategy, attempt,
                    stopwatch.ElapsedMilliseconds, inputTokens, outputTokens);
                return parsed;
            }
            catch (HttpRequestException) when (attempt < _options.MaxAttempts)
            {
                await Task.Delay(TimeSpan.FromMilliseconds(200), timeout.Token);
            }
            catch (HttpRequestException)
            {
                throw new HealthParserException("nutrition.ai_unavailable", true);
            }
        }
        throw new HealthParserException("nutrition.ai_unavailable", true);
    }

    private byte[] BuildRequest(HealthParseRequest request, IReadOnlyDictionary<string, string> sources) =>
        JsonSerializer.SerializeToUtf8Bytes(new
        {
            store = false,
            systemInstruction = new
            {
                parts = new[] { new { text = OpenAiHealthParserContract.Instructions } }
            },
            contents = new[]
            {
                new
                {
                    role = "user",
                    parts = new[]
                    {
                        new
                        {
                            text = JsonSerializer.Serialize(new
                            {
                                schemaVersion = request.SchemaVersion,
                                dictionaryRevision = request.DictionaryRevision,
                                sources,
                                knowledgeGraph = new
                                {
                                    schemaVersion = request.Graph.SchemaVersion,
                                    revision = request.Graph.Revision,
                                    retrievalStrategy = request.Graph.RetrievalStrategy,
                                    nodes = request.Graph.Nodes,
                                    edges = request.Graph.Edges
                                }
                            }, NutritionJson.Options)
                        }
                    }
                }
            },
            generationConfig = new
            {
                maxOutputTokens = _options.MaxOutputTokens,
                responseFormat = new
                {
                    text = new
                    {
                        mimeType = "APPLICATION_JSON",
                        schema = OpenAiHealthParserContract.Schema
                    }
                }
            }
        }, NutritionJson.Options);

    private static HealthParseResult ParseResponse(byte[] body, HealthParseRequest request,
        IReadOnlyDictionary<string, string> redacted, out (long InputTokens, long OutputTokens) usage)
    {
        try
        {
            using var response = JsonDocument.Parse(body);
            var root = response.RootElement;
            if (!root.TryGetProperty("candidates", out var candidates) || candidates.ValueKind != JsonValueKind.Array ||
                candidates.GetArrayLength() == 0)
            {
                var refused = root.TryGetProperty("promptFeedback", out var feedback) &&
                              feedback.TryGetProperty("blockReason", out var blockReason) &&
                              blockReason.ValueKind == JsonValueKind.String;
                throw new HealthParserException(refused ? "nutrition.ai_refused" : "nutrition.ai_invalid_output",
                    false);
            }
            var candidate = candidates[0];
            var finishReason = candidate.TryGetProperty("finishReason", out var finish)
                ? finish.GetString()
                : null;
            if (!string.Equals(finishReason, "STOP", StringComparison.Ordinal))
            {
                var refused = finishReason is "SAFETY" or "BLOCKLIST" or "PROHIBITED_CONTENT" or "SPII";
                throw new HealthParserException(refused ? "nutrition.ai_refused" : "nutrition.ai_invalid_output",
                    false);
            }
            if (!candidate.TryGetProperty("content", out var content) ||
                !content.TryGetProperty("parts", out var parts) || parts.ValueKind != JsonValueKind.Array)
                throw new HealthParserException("nutrition.ai_invalid_output", false);
            var output = parts.EnumerateArray()
                .Select(part => part.TryGetProperty("text", out var text) && text.ValueKind == JsonValueKind.String
                    ? text.GetString()
                    : null)
                .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
            if (output is null) throw new HealthParserException("nutrition.ai_invalid_output", false);
            usage = ReadUsage(root);
            return HealthParserResponse.Parse(output, request, redacted);
        }
        catch (HealthParserException) { throw; }
        catch (Exception error) when (error is JsonException or InvalidOperationException or ArgumentOutOfRangeException)
        {
            throw new HealthParserException("nutrition.ai_invalid_output", false);
        }
    }

    private static (long InputTokens, long OutputTokens) ReadUsage(JsonElement root)
    {
        if (!root.TryGetProperty("usageMetadata", out var usage) || usage.ValueKind != JsonValueKind.Object)
            return (0, 0);
        return (ReadLong(usage, "promptTokenCount"), ReadLong(usage, "candidatesTokenCount"));
    }

    private static long ReadLong(JsonElement value, string property) =>
        value.TryGetProperty(property, out var item) && item.TryGetInt64(out var number) && number >= 0 ? number : 0;

    private static bool Transient(HttpStatusCode code) => code is HttpStatusCode.RequestTimeout or
        HttpStatusCode.TooManyRequests or HttpStatusCode.InternalServerError or HttpStatusCode.BadGateway or
        HttpStatusCode.ServiceUnavailable or HttpStatusCode.GatewayTimeout;

    private static async Task DelayForRetryAsync(RetryConditionHeaderValue? retry, CancellationToken ct)
    {
        var delay = retry?.Delta ??
                    (retry?.Date is { } date ? date - DateTimeOffset.UtcNow : TimeSpan.FromMilliseconds(200));
        if (delay < TimeSpan.Zero) delay = TimeSpan.Zero;
        await Task.Delay(delay, ct);
    }

    private static async Task<byte[]> ReadLimitedAsync(HttpContent content, int limit, CancellationToken ct)
    {
        await using var source = await content.ReadAsStreamAsync(ct);
        using var target = new MemoryStream();
        var buffer = new byte[8192];
        while (true)
        {
            var read = await source.ReadAsync(buffer, ct);
            if (read == 0) break;
            if (target.Length + read > limit)
                throw new HealthParserException("nutrition.ai_invalid_output", false);
            target.Write(buffer, 0, read);
        }
        return target.ToArray();
    }
}
