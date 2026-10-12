using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class UnconfiguredHealthParser : IHealthDescriptionParser
{
    public Task<IReadOnlyList<HealthFact>> ParseAsync(IReadOnlyDictionary<string, string> sources, CancellationToken ct) =>
        Task.FromException<IReadOnlyList<HealthFact>>(new HealthParserException("nutrition.ai_unavailable", false));
}
