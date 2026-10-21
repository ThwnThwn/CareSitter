using CareSitter.Nutrition.Application;
namespace CareSitter.Nutrition.Infrastructure;

internal sealed class UnconfiguredHealthParser : IHealthDescriptionParser
{
    public bool IsReady => false;
    public string? PromptVersion => null;

    public Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct) =>
        Task.FromException<HealthParseResult>(new HealthParserException("nutrition.ai_not_configured", false));
}
