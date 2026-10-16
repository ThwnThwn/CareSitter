using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed record HealthParserOptions
{
    public const string SectionName = "HealthParser";
    public bool Enabled { get; init; }
    public string Provider { get; init; } = "OpenAI";
    public string Model { get; init; } = "gpt-6-luna";
    public string BaseUrl { get; init; } = "https://api.openai.com/v1/";
    public string ApiKey { get; init; } = "";
    public string ApiKeyFile { get; init; } = "";
    public bool DataProcessingApproved { get; init; }
    public int TimeoutSeconds { get; init; } = 25;
    public int MaxOutputTokens { get; init; } = 2048;
    public int MaxAttempts { get; init; } = 2;
    public int MaxConcurrency { get; init; } = 4;
    // Maximum outbound provider attempts in one UTC day, including transport retries.
    public int DailyBudget { get; init; } = 1000;
    public int MaxInputCharacters { get; init; } = 12000;
    public int MaxResponseBytes { get; init; } = 262144;

    public string ReadApiKey()
    {
        if (!string.IsNullOrWhiteSpace(ApiKey)) return ApiKey.Trim();
        return string.IsNullOrWhiteSpace(ApiKeyFile) ? "" : File.ReadAllText(ApiKeyFile).Trim();
    }
}

internal sealed class HealthParserOptionsValidator : IValidateOptions<HealthParserOptions>
{
    public ValidateOptionsResult Validate(string? name, HealthParserOptions options)
    {
        if (!options.Enabled) return ValidateOptionsResult.Success;
        if (!string.Equals(options.Provider, "OpenAI", StringComparison.Ordinal))
            return Fail("HealthParser:Provider must be OpenAI for the initial adapter.");
        if (!string.Equals(options.Model, "gpt-6-luna", StringComparison.Ordinal))
            return Fail("HealthParser:Model must be gpt-6-luna until another model passes the provider evaluation gate.");
        if (!Uri.TryCreate(options.BaseUrl, UriKind.Absolute, out var baseUri) || baseUri.Scheme != Uri.UriSchemeHttps ||
            !string.Equals(baseUri.Host, "api.openai.com", StringComparison.OrdinalIgnoreCase) ||
            !baseUri.AbsolutePath.TrimEnd('/').Equals("/v1", StringComparison.Ordinal))
            return Fail("HealthParser:BaseUrl must be https://api.openai.com/v1/.");
        if (!options.DataProcessingApproved)
            return Fail("HealthParser:DataProcessingApproved must be true before external health-text processing is enabled.");
        if (!string.IsNullOrWhiteSpace(options.ApiKey) && !string.IsNullOrWhiteSpace(options.ApiKeyFile))
            return Fail("Configure only one of HealthParser:ApiKey or HealthParser:ApiKeyFile.");
        string apiKey;
        try { apiKey = options.ReadApiKey(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        { return Fail("HealthParser API key file cannot be read."); }
        if (apiKey.Length is < 20 or > 512)
            return Fail("HealthParser API key must contain 20..512 characters.");
        if (options.TimeoutSeconds is < 1 or > 25 || options.MaxOutputTokens is < 256 or > 4096 ||
            options.MaxAttempts is < 1 or > 2 || options.MaxConcurrency is < 1 or > 16 ||
            options.DailyBudget is < 1 or > 100000 || options.MaxInputCharacters is < 1000 or > 16000 ||
            options.MaxResponseBytes is < 16384 or > 1048576)
            return Fail("HealthParser limits are outside the supported safety range.");
        return ValidateOptionsResult.Success;
    }

    private static ValidateOptionsResult Fail(string message) => ValidateOptionsResult.Fail(message);
}
