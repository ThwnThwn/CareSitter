using System.Text.Json;

namespace CareSitter.Nutrition.Application;

public sealed record ResourceResponse(Guid Id, Guid BeneficiaryId, long HealthRevision,
    string Status, JsonElement Data, DateTimeOffset CreatedAt);
