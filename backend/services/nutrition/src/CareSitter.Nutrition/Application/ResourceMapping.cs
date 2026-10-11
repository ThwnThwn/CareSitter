using System.Text.Json;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

internal static class ResourceMapping
{
    public static ResourceResponse Map(NutritionResource r, long currentRevision)
    {
        using var doc = JsonDocument.Parse(r.Payload);
        return new(r.Id, r.BeneficiaryId, r.HealthRevision, r.HealthRevision == currentRevision ? r.Status : "stale", doc.RootElement.Clone(), r.CreatedAt);
    }
}
