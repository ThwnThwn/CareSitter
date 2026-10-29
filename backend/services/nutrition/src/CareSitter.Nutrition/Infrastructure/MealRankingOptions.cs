using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed record MealRankingOptions
{
    public const string SectionName = "MealRanking";
    public bool Enabled { get; init; }
    public string Model { get; init; } = HealthParserProviders.GeminiModel;
    public string BaseUrl { get; init; } = HealthParserProviders.GeminiBaseUrl;
    public string ApiKey { get; init; } = "";
    public string ApiKeyFile { get; init; } = "";
    public bool DataProcessingApproved { get; init; }
    public int TimeoutSeconds { get; init; } = 20;
    public int MaxOutputTokens { get; init; } = 1536;
    public int MaxAttempts { get; init; } = 2;
    public int MaxConcurrency { get; init; } = 4;
    public int DailyBudget { get; init; } = 1000;
    public int MaxResponseBytes { get; init; } = 131072;
    public int MaxCandidateSets { get; init; } = 12;

    public string ReadApiKey()
    {
        if (!string.IsNullOrWhiteSpace(ApiKey)) return ApiKey.Trim();
        return string.IsNullOrWhiteSpace(ApiKeyFile) ? "" : File.ReadAllText(ApiKeyFile).Trim();
    }
}

internal sealed class MealRankingOptionsValidator : IValidateOptions<MealRankingOptions>
{
    public ValidateOptionsResult Validate(string? name, MealRankingOptions options)
    {
        if (!options.Enabled) return ValidateOptionsResult.Success;
        if (!HealthParserProviders.IsSupportedModel(HealthParserProviders.Gemini, options.Model) ||
            !HealthParserProviders.IsSupportedBaseUrl(HealthParserProviders.Gemini, options.BaseUrl))
            return Fail("MealRanking requires an approved Gemini model and base URL.");
        if (!options.DataProcessingApproved)
            return Fail("MealRanking:DataProcessingApproved must be true before external ranking is enabled.");
        if (!string.IsNullOrWhiteSpace(options.ApiKey) && !string.IsNullOrWhiteSpace(options.ApiKeyFile))
            return Fail("Configure only one of MealRanking:ApiKey or MealRanking:ApiKeyFile.");
        string apiKey;
        try { apiKey = options.ReadApiKey(); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { return Fail("MealRanking API key file cannot be read."); }
        if (apiKey.Length is < 20 or > 512) return Fail("MealRanking API key must contain 20..512 characters.");
        if (options.TimeoutSeconds is < 1 or > 25 || options.MaxOutputTokens is < 256 or > 4096 ||
            options.MaxAttempts is < 1 or > 2 || options.MaxConcurrency is < 1 or > 16 ||
            options.DailyBudget is < 1 or > 100000 || options.MaxResponseBytes is < 16384 or > 1048576 ||
            options.MaxCandidateSets is < 2 or > 20)
            return Fail("MealRanking limits are outside the supported safety range.");
        return ValidateOptionsResult.Success;
    }

    private static ValidateOptionsResult Fail(string message) => ValidateOptionsResult.Fail(message);
}
