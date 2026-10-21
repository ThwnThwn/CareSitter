using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Domain;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionCatalogReader(
    NpgsqlConnection connection,
    NpgsqlTransaction transaction,
    LocalDemoCatalogOptions localDemo)
{
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
        var published = (long)(await c.ExecuteScalarAsync(ct))!;
        if (!localDemo.Enabled) return published;
        await using var demo = Command("SELECT revision FROM nutrition.local_demo_catalog WHERE package_key=@key");
        demo.Parameters.AddWithValue("key", localDemo.PackageKey);
        var revision = await demo.ExecuteScalarAsync(ct);
        return revision is long localRevision ? checked(published * 1_000_000 + localRevision) : published;
    }
    public async Task<IReadOnlyList<Recipe>> RecipesAsync(CancellationToken ct)
    {
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
                    var recipe = NutritionJson.Read<Recipe>(r.GetString(1));
                    values.Add(recipe with { VersionId = r.GetGuid(0), SourceDetails = NutritionJson.Read<RecipeSource[]>(r.GetString(2)) });
                }
                catch (JsonException) { /* Nội dung hoặc metadata nguồn sai schema không được đưa vào gợi ý. */ }
            }
        }
        var demo = await LocalDemoAsync(ct);
        if (demo is not null)
        {
            var citations = demo.Value.Bundle.Citations.ToDictionary(value => value.Id, StringComparer.Ordinal);
            foreach (var version in demo.Value.Bundle.Recipes)
            {
                var details = version.Payload.Sources
                    .Where(citations.ContainsKey)
                    .Select(source => Source(citations[source]))
                    .ToArray();
                values.Add(version.Payload with { SourceDetails = details });
            }
        }
        return values;
    }
    public async Task<IReadOnlyList<DietaryRule>> RulesAsync(CancellationToken ct) =>
        await CatalogAsync<DietaryRule>("nutrition.rule_versions", (value, id) => value with { VersionId = id }, ct);
    private async Task<IReadOnlyList<T>> CatalogAsync<T>(string table, Func<T, Guid, T> version, CancellationToken ct)
    {
        await using var c = Command($"SELECT id,payload::text FROM {table} WHERE status='published' ORDER BY id LIMIT 1000");
        await using var r = await c.ExecuteReaderAsync(ct); var values = new List<T>();
        while (await r.ReadAsync(ct))
        {
            try { values.Add(version(NutritionJson.Read<T>(r.GetString(1)), r.GetGuid(0))); }
            catch (JsonException) { /* Nội dung sai schema không được đưa vào gợi ý. */ }
        }
        return values;
    }

    private async Task<(CatalogBundle Bundle, long Revision)?> LocalDemoAsync(CancellationToken ct)
    {
        if (!localDemo.Enabled) return null;
        await using var command = Command("SELECT payload::text,revision FROM nutrition.local_demo_catalog WHERE package_key=@key");
        command.Parameters.AddWithValue("key", localDemo.PackageKey);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return null;
        try { return (NutritionJson.Read<CatalogBundle>(reader.GetString(0)), reader.GetInt64(1)); }
        catch (JsonException) { return null; }
    }

    private static RecipeSource Source(CatalogCitation value) => new(
        value.Id, value.Title, value.Organization, value.Year, value.Edition, value.Chapter,
        value.PrintedPages, value.PdfPages, value.Locator, value.Reference, value.VerifiedOn);
}
