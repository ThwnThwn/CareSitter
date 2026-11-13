using System.Text.Json;
using System.Security.Cryptography;
using System.Text;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Domain;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionCatalogReader(
    NpgsqlConnection connection,
    NpgsqlTransaction transaction,
    LocalDemoCatalogOptions localDemo, bool allowNonMedicalReference = false)
{
    private (CatalogBundle Bundle, long Revision)? _demo;
    private NpgsqlCommand Command(string sql) => new(sql, connection, transaction);

    public async Task<IReadOnlyList<NutritionConcept>> ConceptsAsync(CancellationToken ct)
    {
        var result = new List<NutritionConcept>();
        await using (var c = Command("SELECT code,kind,aliases::text,version FROM nutrition.concepts ORDER BY code LIMIT 2000"))
        await using (var r = await c.ExecuteReaderAsync(ct))
            while (await r.ReadAsync(ct)) result.Add(new(r.GetString(0), r.GetString(1), NutritionJson.Read<string[]>(r.GetString(2)), r.GetInt32(3)));
        var demo = await LocalDemoAsync(ct);
        if (demo is not null)
        {
            var known = result.Select(value => value.Code).ToHashSet(StringComparer.Ordinal);
            result.AddRange(demo.Value.Bundle.Concepts.Where(value => known.Add(value.Code)));
        }
        return result;
    }
    public async Task<long> CatalogRevisionAsync(CancellationToken ct)
    {
        await using var c = Command("SELECT revision FROM nutrition.catalog_state WHERE id=1 FOR SHARE");
        if (await c.ExecuteScalarAsync(ct) is not long published || published < 1)
            throw new InvalidOperationException("Nutrition catalog revision is missing or invalid.");
        await using (var integrity = Command("SELECT nutrition.published_catalog_integrity()"))
            if (await integrity.ExecuteScalarAsync(ct) is not true)
                throw new InvalidOperationException("Nutrition published catalog digest or materialized payload is missing or inconsistent.");
        if (!localDemo.Enabled) return published;
        var demo = (await LocalDemoAsync(ct))!.Value;
        return checked(published * 1_000_000 + demo.Revision);
    }
    public async Task<IReadOnlyList<Recipe>> RecipesAsync(CancellationToken ct)
    {
        await CatalogRevisionAsync(ct);
        var values = new List<Recipe>();
        await using (var c = Command("""
                SELECT recipe.id,recipe.payload::text,
                  coalesce(jsonb_agg(jsonb_build_object(
                    'id',source.source_id,'title',source.title,'organization',source.organization,'year',source.year,
                    'edition',source.edition,'chapter',source.chapter,'printedPages',source.printed_pages,
                    'pdfPages',source.pdf_pages,'locator',source.locator,'reference',source.reference,
                    'verifiedOn',to_char(source.verified_on,'YYYY-MM-DD')) ORDER BY source.source_id)
                    FILTER (WHERE source.source_id IS NOT NULL),'[]'::jsonb)::text
                FROM nutrition.recipe_versions recipe
                LEFT JOIN nutrition.recipe_source_citations source ON source.recipe_version_id=recipe.id
                WHERE recipe.status='published'
                GROUP BY recipe.id,recipe.payload
                ORDER BY recipe.id LIMIT 1000
                """))
        await using (var r = await c.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                try
                {
                    var recipe = ReadRecipePayload(r.GetString(1), allowNonMedicalReference);
                    if (recipe is null) continue;
                    values.Add(recipe with { VersionId = r.GetGuid(0), SourceDetails = NutritionJson.Read<RecipeSource[]>(r.GetString(2)) });
                }
                catch (Exception error) when (error is JsonException or InvalidOperationException or KeyNotFoundException) { /* Nội dung hoặc metadata nguồn sai schema không được đưa vào gợi ý. */ }
            }
        }
        var demo = await LocalDemoAsync(ct);
        if (demo is not null)
        {
            var citations = demo.Value.Bundle.Citations.ToDictionary(value => value.Id, StringComparer.Ordinal);
            foreach (var version in demo.Value.Bundle.Recipes)
            {
                var recipe = ReadRecipePayload(NutritionJson.Write(version.Payload), allowNonMedicalReference);
                if (recipe is null) continue;
                var details = version.Payload.Sources
                    .Where(citations.ContainsKey)
                    .Select(source => Source(citations[source]))
                    .ToArray();
                values.Add(recipe with { SourceDetails = details });
            }
        }
        return values;
    }
    internal static Recipe? ReadRecipePayload(string json, bool allowNonMedicalReference)
    {
        using var payload = JsonDocument.Parse(json);
        var root = payload.RootElement;
        if (new[] { "review_policy", "intended_use", "clinical_review_performed", "independent_clinical_review",
                "production_public_release", "clinical_review_not_performed_reason" }
            .Any(key => root.TryGetProperty(key, out _)))
        {
            var policy = ReleaseReviewPolicy.Read(root);
            if (policy == ReleaseReviewPolicy.Reference && !allowNonMedicalReference)
                return null;
        }
        return NutritionJson.Read<Recipe>(json);
    }

    public async Task<IReadOnlyList<DietaryRule>> RulesAsync(CancellationToken ct)
    {
        await CatalogRevisionAsync(ct);
        return await CatalogAsync<DietaryRule>("nutrition.rule_versions", (value, id) => value with { VersionId = id }, ct);
    }
    private async Task<IReadOnlyList<T>> CatalogAsync<T>(string table, Func<T, Guid, T> version, CancellationToken ct)
    {
        await using var c = Command($"SELECT id,payload::text FROM {table} WHERE status='published' ORDER BY id LIMIT 1000");
        await using var r = await c.ExecuteReaderAsync(ct); var values = new List<T>();
        while (await r.ReadAsync(ct))
        {
            try { values.Add(version(NutritionJson.Read<T>(r.GetString(1)), r.GetGuid(0))); }
            catch (Exception error) when (error is JsonException or InvalidOperationException or KeyNotFoundException) { /* Nội dung sai schema không được đưa vào gợi ý. */ }
        }
        return values;
    }

    private async Task<(CatalogBundle Bundle, long Revision)?> LocalDemoAsync(CancellationToken ct)
    {
        if (!localDemo.Enabled) return null;
        if (_demo is not null) return _demo;
        // Keep payload and metadata together for this session; the runtime role remains read-only.
        await using var command = Command("SELECT payload::text,revision,payload_digest FROM nutrition.local_demo_catalog WHERE package_key=@key");
        command.Parameters.AddWithValue("key", localDemo.PackageKey);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct) || reader.IsDBNull(0) || reader.IsDBNull(1) ||
            reader.GetInt64(1) is < 1 or >= 1_000_000 || reader.IsDBNull(2))
            throw new InvalidOperationException("Nutrition local demo catalog or revision/digest is missing or invalid.");
        var json = reader.GetString(0);
        var digest = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))).ToLowerInvariant();
        if (!string.Equals(digest, reader.GetString(2), StringComparison.Ordinal))
            throw new InvalidOperationException("Nutrition local demo catalog digest is missing or does not match its payload.");
        try
        {
            var bundle = NutritionJson.Read<CatalogBundle>(json);
            if (bundle.PackageKey != localDemo.PackageKey || bundle.Recipes is null || bundle.Rules is null ||
                bundle.Concepts is null || bundle.Citations is null || bundle.SupportedScopes is null ||
                !CatalogBundleValidator.Validate(bundle).IsValid)
                throw new InvalidOperationException("Nutrition local demo catalog payload is invalid.");
            _demo = (bundle, reader.GetInt64(1));
            return _demo;
        }
        catch (JsonException error)
        { throw new InvalidOperationException("Nutrition local demo catalog payload is invalid.", error); }
    }

    private static RecipeSource Source(CatalogCitation value) => new(
        value.Id, value.Title, value.Organization, value.Year, value.Edition, value.Chapter,
        value.PrintedPages, value.PdfPages, value.Locator, value.Reference, value.VerifiedOn);
}
