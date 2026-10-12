using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public interface IHealthDescriptionParser
{
    Task<IReadOnlyList<HealthFact>> ParseAsync(IReadOnlyDictionary<string, string> sources, CancellationToken ct);
}
