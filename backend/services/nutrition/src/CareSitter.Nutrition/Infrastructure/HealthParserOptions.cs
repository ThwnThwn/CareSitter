using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed record HealthParserOptions
{
    public const string SectionName = "HealthParser";
    public bool Enabled { get; init; }
    public string Provider { get; init; } = "OpenAI";
    public string Model { get; init; } = "";
    public string BaseUrl { get; init; } = "";
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

    public string EffectiveModel => !string.IsNullOrWhiteSpace(Model)
        ? Model.Trim()
        : HealthParserProviders.DefaultModel(Provider);

    public string EffectiveBaseUrl => !string.IsNullOrWhiteSpace(BaseUrl)
        ? BaseUrl.Trim()
        : HealthParserProviders.DefaultBaseUrl(Provider);

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
        if (!HealthParserProviders.IsSupported(options.Provider))
            return Fail("HealthParser:Provider must be OpenAI or Gemini.");
        if (!HealthParserProviders.IsSupportedModel(options.Provider, options.EffectiveModel))
            return Fail($"HealthParser:Model is not approved for provider {options.Provider}.");
        if (!HealthParserProviders.IsSupportedBaseUrl(options.Provider, options.EffectiveBaseUrl))
            return Fail($"HealthParser:BaseUrl is not approved for provider {options.Provider}.");
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

internal static class HealthParserProviders
{
    public const string OpenAi = "OpenAI";
    public const string Gemini = "Gemini";
    public const string OpenAiModel = "gpt-6-luna";
    public const string GeminiModel = "gemini-3.5-flash-lite";
    public const string GeminiFlashModel = "gemini-3.8-flash";
    public const string OpenAiBaseUrl = "https://api.openai.com/v1/";
    public const string GeminiBaseUrl = "https://generativelanguage.googleapis.com/v1beta/";

    public static bool IsOpenAi(string provider) =>
        string.Equals(provider, OpenAi, StringComparison.OrdinalIgnoreCase);

    public static bool IsGemini(string provider) =>
        string.Equals(provider, Gemini, StringComparison.OrdinalIgnoreCase);

    public static bool IsSupported(string provider) => IsOpenAi(provider) || IsGemini(provider);

    public static string DefaultModel(string provider) => IsGemini(provider) ? GeminiModel : OpenAiModel;

    public static string DefaultBaseUrl(string provider) => IsGemini(provider) ? GeminiBaseUrl : OpenAiBaseUrl;

    public static bool IsSupportedModel(string provider, string model) =>
        IsOpenAi(provider) && string.Equals(model, OpenAiModel, StringComparison.Ordinal) ||
        IsGemini(provider) && (string.Equals(model, GeminiModel, StringComparison.Ordinal) ||
                               string.Equals(model, GeminiFlashModel, StringComparison.Ordinal));

    public static bool IsSupportedBaseUrl(string provider, string value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps ||
            !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment)) return false;
        var path = uri.AbsolutePath.TrimEnd('/');
        return IsOpenAi(provider) && string.Equals(uri.Host, "api.openai.com", StringComparison.OrdinalIgnoreCase) &&
                   string.Equals(path, "/v1", StringComparison.Ordinal) ||
               IsGemini(provider) && string.Equals(uri.Host, "generativelanguage.googleapis.com", StringComparison.OrdinalIgnoreCase) &&
                   string.Equals(path, "/v1beta", StringComparison.Ordinal);
    }
}
