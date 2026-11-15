namespace CareSitter.Nutrition.Application;

public interface IHealthDescriptionParser
{
    bool IsReady { get; }
    string? PromptVersion { get; }
    Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct);
}
