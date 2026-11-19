using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

internal static class ResourceMapping
{
    public static ResourceResponse Map(NutritionResource r, long currentRevision)
    {
        var data = JsonNode.Parse(r.Payload);
        if (data is JsonObject payload)
        {
            // Preserve plan identity for historical feedback even when health/catalog has changed.
            if (r.Status == "saved") payload["isSavedPlan"] = true;
            if (payload["meals"] is JsonArray meals)
            {
                foreach (var meal in meals.OfType<JsonObject>())
                    RecipePresentation.NormalizeName(meal);
            }
        }
        return new(r.Id, r.BeneficiaryId, r.HealthRevision, r.HealthRevision == currentRevision ? r.Status : "stale",
            JsonSerializer.SerializeToElement(data), r.CreatedAt);
    }
}
