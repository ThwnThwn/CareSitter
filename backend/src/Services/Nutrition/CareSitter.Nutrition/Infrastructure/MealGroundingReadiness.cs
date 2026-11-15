using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;
using Npgsql;
using System.Text.Json;

namespace CareSitter.Nutrition.Infrastructure;

internal static class MealGroundingReadiness
{
    // The caller checks published_catalog_integrity before reading these policy fields.
    internal static async Task<string?> CatalogPolicyFailureAsync(NpgsqlDataSource db, bool allowReference, CancellationToken ct)
    {
        await using var connection = await db.OpenConnectionAsync(ct);
        await using var command = new NpgsqlCommand("""
            SELECT payload::text FROM nutrition.recipe_versions
            WHERE status='published' AND payload ?| ARRAY['review_policy','intended_use',
              'clinical_review_performed','independent_clinical_review',
              'production_public_release','clinical_review_not_performed_reason']
            """, connection);
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            try
            {
                using var payload = JsonDocument.Parse(reader.GetString(0));
                if (ReleaseReviewPolicy.Read(payload.RootElement) == ReleaseReviewPolicy.Reference && !allowReference)
                    return ReleaseReviewPolicy.NotAllowed;
            }
            catch (Exception error) when (error is JsonException or InvalidOperationException or KeyNotFoundException)
            {
                return "grounding_release_invalid";
            }
        }
        return null;
    }

    public static async Task<(bool Available, string Status, string[] Reasons)> CheckAsync(
        IOptions<MealGroundingOptions> options, IMealKnowledgeRetriever retriever, CancellationToken ct)
    {
        var settings = options.Value;
        if (!settings.Enabled || settings.Mode is not (MealGroundingOptions.ReleasedGraphMode or MealGroundingOptions.ReleasedRetrievalMode))
            return (true, "not_required", []);
        var result = await retriever.RetrieveAsync(new([], [], [], "", ""), ct);
        return result.Available ? (true, "available", []) : (false, "grounding unavailable", result.Warnings);
    }
}
