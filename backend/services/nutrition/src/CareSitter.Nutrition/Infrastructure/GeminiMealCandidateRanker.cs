using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class GeminiMealCandidateRanker(HttpClient http, IOptions<MealRankingOptions> configured,
    MealRankingRuntimeGuard guard, ILogger<GeminiMealCandidateRanker> logger) : IMealCandidateRanker
{
    internal const string PromptVersion = "meal-ranker-v1";
    private readonly MealRankingOptions _options = configured.Value;

    public async Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request,
        CancellationToken ct)
    {
        if (!_options.Enabled) return MealCandidateRankingResult.Unavailable("meal_ranking_not_configured");
        if (request.Evidence.Length == 0 || request.CandidateSets.Length < 2)
            return MealCandidateRankingResult.Unavailable("meal_ranking_insufficient_context");
        using var concurrency = await guard.EnterAsync(ct);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));
        var requestBody = BuildRequest(request);
        for (var attempt = 1; attempt <= _options.MaxAttempts; attempt++)
        {
            if (!guard.TryConsumeAttempt())
                return MealCandidateRankingResult.Unavailable("meal_ranking_budget_exhausted");
            try
            {
                using var message = new HttpRequestMessage(HttpMethod.Post,
                    $"models/{Uri.EscapeDataString(_options.Model)}:generateContent")
                {
                    Content = new ByteArrayContent(requestBody)
                };
                message.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                message.Headers.Add("x-goog-api-key", _options.ReadApiKey());
                using var response = await http.SendAsync(message, HttpCompletionOption.ResponseHeadersRead,
                    timeout.Token);
                if (Transient(response.StatusCode) && attempt < _options.MaxAttempts)
                {
                    await Task.Delay(TimeSpan.FromMilliseconds(200), timeout.Token);
                    continue;
                }
                if (!response.IsSuccessStatusCode)
                {
                    logger.LogWarning(
                        "Nutrition meal ranker failed: Model={Model}, StatusCode={StatusCode}, Attempt={Attempt}.",
                        _options.Model, (int)response.StatusCode, attempt);
                    return MealCandidateRankingResult.Unavailable(response.StatusCode == HttpStatusCode.TooManyRequests
                        ? "meal_ranking_rate_limited" : "meal_ranking_unavailable");
                }
                var body = await ReadLimitedAsync(response.Content, _options.MaxResponseBytes, timeout.Token);
                return ParseResponse(body, request);
            }
            catch (HttpRequestException) when (attempt < _options.MaxAttempts)
            {
                await Task.Delay(TimeSpan.FromMilliseconds(200), timeout.Token);
            }
            catch (HttpRequestException)
            {
                return MealCandidateRankingResult.Unavailable("meal_ranking_unavailable");
            }
            catch (JsonException)
            {
                return MealCandidateRankingResult.Unavailable("meal_ranking_invalid_output");
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                return MealCandidateRankingResult.Unavailable("meal_ranking_timeout");
            }
        }
        return MealCandidateRankingResult.Unavailable("meal_ranking_unavailable");
    }

    private byte[] BuildRequest(MealCandidateRankingRequest request) => JsonSerializer.SerializeToUtf8Bytes(new
    {
        store = false,
        systemInstruction = new
        {
            parts = new[]
            {
                new
                {
                    text = "You rank only the supplied, pre-validated meal sets. Select exactly one complete set. " +
                           "Never invent, replace, or mix recipeVersionIds across sets. Use only supplied evidenceIds. " +
                           "Prefer the set best aligned with the stated goal and evidence. Consider recentMeals to favor variety. " +
                           "Return concise Vietnamese explanations."
                }
            }
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
                            catalogRevision = request.CatalogRevision,
                            dietaryPattern = request.DietaryPattern,
                            nutritionGoal = request.NutritionGoal,
                            recentMeals = (request.RecentMeals ?? []).Select(meal => new { meal.Name, meal.MealType }),
                            healthFacts = request.Facts.Where(fact => fact.Subject == "beneficiary")
                                .Select(fact => new { fact.Kind, fact.Code, fact.Label, fact.Assertion, fact.Temporality }),
                            rules = request.Rules.Select(rule => new
                            {
                                rule.ConditionCode, rule.ExcludedIngredients, rule.DailyMaximums,
                                rule.NutrientConstraints
                            }),
                            candidateSets = request.CandidateSets.Take(_options.MaxCandidateSets)
                                .Select((set, index) => new
                                {
                                    index,
                                    meals = set.Select(meal => new
                                    {
                                        recipeVersionId = meal.VersionId,
                                        meal.Name,
                                        meal.MealType,
                                        ingredients = meal.Ingredients.Select(ingredient => ingredient.Name),
                                        meal.Nutrients,
                                        meal.DietaryPatterns
                                    })
                                }),
                            evidence = request.Evidence.Select(item => new
                            {
                                evidenceId = item.Id, item.Title, item.Chapter, item.PrintedPages,
                                item.Locator, item.Excerpt
                            })
                        }, NutritionJson.Options)
                    }
                }
            }
        },
        generationConfig = new
        {
            maxOutputTokens = _options.MaxOutputTokens,
            responseMimeType = "application/json",
            responseJsonSchema = ResponseSchema
        }
    }, NutritionJson.Options);

    private MealCandidateRankingResult ParseResponse(byte[] body, MealCandidateRankingRequest request)
    {
        try
        {
            using var response = JsonDocument.Parse(body);
            var root = response.RootElement;
            var candidates = root.GetProperty("candidates");
            if (candidates.ValueKind != JsonValueKind.Array || candidates.GetArrayLength() == 0)
                return InvalidOutput();
            var candidate = candidates[0];
            if (!candidate.TryGetProperty("finishReason", out var finish) || finish.GetString() != "STOP")
                return InvalidOutput();
            var output = candidate.GetProperty("content").GetProperty("parts").EnumerateArray()
                .Select(part => part.TryGetProperty("text", out var text) ? text.GetString() : null)
                .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
            if (output is null) return InvalidOutput();
            var ranked = NutritionJson.Read<RankedOutput>(output);
            var selectedIds = ranked.SelectedRecipeVersionIds;
            var selectedSet = request.CandidateSets.FirstOrDefault(set =>
                set.Select(meal => meal.VersionId).SequenceEqual(selectedIds));
            if (selectedSet is null || selectedIds.Distinct().Count() != 3) return InvalidOutput();
            var evidenceIds = request.Evidence.Select(item => item.Id).ToHashSet(StringComparer.Ordinal);
            if (ranked.Explanations.Length != 3 || ranked.Explanations.Any(explanation =>
                    !selectedIds.Contains(explanation.RecipeVersionId) ||
                    explanation.Summary is not { Length: > 0 and <= 300 } ||
                    explanation.EvidenceIds.Length == 0 ||
                    explanation.EvidenceIds.Any(id => !evidenceIds.Contains(id))) ||
                ranked.Explanations.Select(explanation => explanation.RecipeVersionId).Distinct().Count() != 3)
                return InvalidOutput();
            return new(true, selectedIds, _options.Model, PromptVersion, ranked.Explanations, []);
        }
        catch (Exception error) when (error is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            return InvalidOutput();
        }
    }

    private static MealCandidateRankingResult InvalidOutput() =>
        MealCandidateRankingResult.Unavailable("meal_ranking_invalid_output");

    private static bool Transient(HttpStatusCode code) => code is HttpStatusCode.RequestTimeout or
        HttpStatusCode.TooManyRequests or HttpStatusCode.InternalServerError or HttpStatusCode.BadGateway or
        HttpStatusCode.ServiceUnavailable or HttpStatusCode.GatewayTimeout;

    private static async Task<byte[]> ReadLimitedAsync(HttpContent content, int limit, CancellationToken ct)
    {
        await using var source = await content.ReadAsStreamAsync(ct);
        using var target = new MemoryStream();
        var buffer = new byte[8192];
        while (true)
        {
            var read = await source.ReadAsync(buffer, ct);
            if (read == 0) break;
            if (target.Length + read > limit) throw new JsonException("Meal ranking response is too large.");
            target.Write(buffer, 0, read);
        }
        return target.ToArray();
    }

    private static readonly JsonElement ResponseSchema = JsonDocument.Parse("""
        {
          "type": "object",
          "additionalProperties": false,
          "required": ["selectedRecipeVersionIds", "explanations"],
          "properties": {
            "selectedRecipeVersionIds": {
              "type": "array", "minItems": 3, "maxItems": 3,
              "items": { "type": "string", "format": "uuid" }
            },
            "explanations": {
              "type": "array", "minItems": 3, "maxItems": 3,
              "items": {
                "type": "object", "additionalProperties": false,
                "required": ["recipeVersionId", "summary", "evidenceIds"],
                "properties": {
                  "recipeVersionId": { "type": "string", "format": "uuid" },
                  "summary": { "type": "string" },
                  "evidenceIds": { "type": "array", "minItems": 1, "items": { "type": "string" } }
                }
              }
            }
          }
        }
        """).RootElement.Clone();

    private sealed record RankedOutput(Guid[] SelectedRecipeVersionIds,
        MealRecommendationExplanation[] Explanations);
}
