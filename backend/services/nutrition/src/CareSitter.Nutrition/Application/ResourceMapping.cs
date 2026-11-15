using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

internal static class ResourceMapping
{
    public static ResourceResponse Map(NutritionResource r, long currentRevision)
    {
        using var doc = JsonDocument.Parse(r.Payload);
        var data = doc.RootElement.Clone();
        if (r.Status == "saved" && JsonNode.Parse(r.Payload) is JsonObject plan)
        {
            // Preserve plan identity for historical feedback even when health/catalog has changed.
            plan["isSavedPlan"] = true;
            data = JsonSerializer.SerializeToElement(plan);
        }
        return new(r.Id, r.BeneficiaryId, r.HealthRevision, r.HealthRevision == currentRevision ? r.Status : "stale", data, r.CreatedAt);
    }
}
