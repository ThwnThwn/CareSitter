using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class OpenAiHealthDescriptionParser(HttpClient http, IOptions<HealthParserOptions> configured,
    HealthParserRuntimeGuard guard, ILogger<OpenAiHealthDescriptionParser> logger) : IHealthDescriptionParser
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
        var idempotencyKey = Guid.NewGuid().ToString("N");
        var stopwatch = Stopwatch.StartNew();
        var inputTokens = 0L; var outputTokens = 0L;
        for (var attempt = 1; attempt <= _options.MaxAttempts; attempt++)
        {
            if (!guard.TryConsumeAttempt()) throw new HealthParserException("nutrition.ai_budget_exhausted", false);
            try
            {
                using var message = new HttpRequestMessage(HttpMethod.Post, "responses")
                {
                    Content = new ByteArrayContent(requestBody)
                };
                message.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ReadApiKey());
                message.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                message.Headers.Add("Idempotency-Key", idempotencyKey);
                using var response = await http.SendAsync(message, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
                if (Transient(response.StatusCode) && attempt < _options.MaxAttempts)
                {
                    await DelayForRetryAsync(response.Headers.RetryAfter, timeout.Token); continue;
                }
                if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
                {
                    logger.LogWarning(
                        "Nutrition AI provider rejected its credential: StatusCode={StatusCode}, ErrorCode={ErrorCode}.",
                        (int)response.StatusCode, "nutrition.ai_authentication_failed");
                    throw new HealthParserException("nutrition.ai_authentication_failed", false);
                }
                if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.NotFound)
                {
                    logger.LogWarning(
                        "Nutrition AI provider rejected its request configuration: StatusCode={StatusCode}, ErrorCode={ErrorCode}.",
                        (int)response.StatusCode, "nutrition.ai_configuration_invalid");
                    throw new HealthParserException("nutrition.ai_configuration_invalid", false);
                }
                if (response.StatusCode is HttpStatusCode.TooManyRequests)
                    throw new HealthParserException("nutrition.ai_rate_limited", true);
                if (!response.IsSuccessStatusCode)
                    throw new HealthParserException("nutrition.ai_unavailable", Transient(response.StatusCode));
                var body = await ReadLimitedAsync(response.Content, _options.MaxResponseBytes, timeout.Token);
                var parsed = ParseResponse(body, request, redacted, out var usage);
                inputTokens += usage.InputTokens; outputTokens += usage.OutputTokens;
                logger.LogInformation("Nutrition GraphRAG parser completed: Provider={Provider}, Model={Model}, Prompt={Prompt}, Schema={Schema}, Dictionary={Dictionary}, GraphSchema={GraphSchema}, GraphNodes={GraphNodes}, GraphEdges={GraphEdges}, Retrieval={Retrieval}, Attempts={Attempts}, LatencyMs={LatencyMs}, InputTokens={InputTokens}, OutputTokens={OutputTokens}.",
                    _options.Provider, _options.EffectiveModel, OpenAiHealthParserContract.PromptVersion, request.SchemaVersion,
                    request.DictionaryRevision, request.Graph.SchemaVersion, request.Graph.Nodes.Length,
                    request.Graph.Edges.Length, request.Graph.RetrievalStrategy, attempt, stopwatch.ElapsedMilliseconds,
                    inputTokens, outputTokens);
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
            model = _options.EffectiveModel,
            store = false,
            reasoning = new { effort = "none" },
            instructions = OpenAiHealthParserContract.Instructions,
            input = JsonSerializer.Serialize(new
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
            }, NutritionJson.Options),
            max_output_tokens = _options.MaxOutputTokens,
            tools = Array.Empty<object>(),
            text = new { format = new { type = "json_schema", name = "nutrition_health_parse", strict = true, schema = OpenAiHealthParserContract.Schema } },
            metadata = new { prompt_version = OpenAiHealthParserContract.PromptVersion, schema_version = request.SchemaVersion.ToString() }
        }, NutritionJson.Options);

    private static HealthParseResult ParseResponse(byte[] body, HealthParseRequest request,
        IReadOnlyDictionary<string, string> redacted, out (long InputTokens, long OutputTokens) usage)
    {
        try
        {
            using var response = JsonDocument.Parse(body);
            var root = response.RootElement;
            if (root.TryGetProperty("status", out var status) && status.GetString() is not "completed")
                throw new HealthParserException("nutrition.ai_invalid_output", false);
            if (!TryOutput(root, out var output, out var refused))
                throw new HealthParserException(refused ? "nutrition.ai_refused" : "nutrition.ai_invalid_output", false);
            var result = HealthParserResponse.Parse(output, request, redacted);
            usage = ReadUsage(root);
            return result;
        }
        catch (HealthParserException) { throw; }
        catch (Exception e) when (e is JsonException or InvalidOperationException or ArgumentOutOfRangeException)
        { throw new HealthParserException("nutrition.ai_invalid_output", false); }
    }

    private static bool TryOutput(JsonElement root, out string output, out bool refused)
    {
        output = ""; refused = false;
        if (!root.TryGetProperty("output", out var items) || items.ValueKind != JsonValueKind.Array) return false;
        foreach (var item in items.EnumerateArray())
        {
            if (!item.TryGetProperty("content", out var content) || content.ValueKind != JsonValueKind.Array) continue;
            foreach (var part in content.EnumerateArray())
            {
                var type = part.TryGetProperty("type", out var typeValue) ? typeValue.GetString() : null;
                if (type == "refusal") { refused = true; return false; }
                if (type == "output_text" && part.TryGetProperty("text", out var text) && text.ValueKind == JsonValueKind.String)
                { output = text.GetString() ?? ""; return output.Length > 0; }
            }
        }
        return false;
    }

    private static (long InputTokens, long OutputTokens) ReadUsage(JsonElement root)
    {
        if (!root.TryGetProperty("usage", out var usage) || usage.ValueKind != JsonValueKind.Object) return (0, 0);
        return (ReadLong(usage, "input_tokens"), ReadLong(usage, "output_tokens"));
    }

    private static long ReadLong(JsonElement value, string property) => value.TryGetProperty(property, out var item) &&
        item.TryGetInt64(out var number) && number >= 0 ? number : 0;

    private static bool Transient(HttpStatusCode code) => code is HttpStatusCode.RequestTimeout or HttpStatusCode.TooManyRequests or
        HttpStatusCode.InternalServerError or HttpStatusCode.BadGateway or HttpStatusCode.ServiceUnavailable or HttpStatusCode.GatewayTimeout;

    private static async Task DelayForRetryAsync(RetryConditionHeaderValue? retry, CancellationToken ct)
    {
        var delay = retry?.Delta ?? (retry?.Date is { } date ? date - DateTimeOffset.UtcNow : TimeSpan.FromMilliseconds(200));
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
            var read = await source.ReadAsync(buffer, ct); if (read == 0) break;
            if (target.Length + read > limit) throw new HealthParserException("nutrition.ai_invalid_output", false);
            target.Write(buffer, 0, read);
        }
        return target.ToArray();
    }
}
