using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionCatalogReader(NpgsqlConnection connection, NpgsqlTransaction transaction)
{
    private NpgsqlCommand Command(string sql) => new(sql, connection, transaction);

    public async Task<IReadOnlyList<NutritionConcept>> ConceptsAsync(CancellationToken ct)
    {
        await using var c = Command("SELECT code,kind,aliases::text,version FROM nutrition.concepts ORDER BY code LIMIT 2000");
        await using var r = await c.ExecuteReaderAsync(ct); var result = new List<NutritionConcept>();
        while (await r.ReadAsync(ct)) result.Add(new(r.GetString(0), r.GetString(1), NutritionJson.Read<string[]>(r.GetString(2)), r.GetInt32(3)));
        return result;
    }
    public async Task<long> CatalogRevisionAsync(CancellationToken ct)
    {
        await using var c = Command("SELECT revision FROM nutrition.catalog_state WHERE id=1 FOR SHARE");
        return (long)(await c.ExecuteScalarAsync(ct))!;
    }
    public async Task<IReadOnlyList<Recipe>> RecipesAsync(CancellationToken ct) =>
        await CatalogAsync<Recipe>("nutrition.recipe_versions", (value, id) => value with { VersionId = id }, ct);
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
    }}
