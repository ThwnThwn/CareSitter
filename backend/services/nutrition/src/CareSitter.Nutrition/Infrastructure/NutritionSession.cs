using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionSession(
    NpgsqlConnection connection,
    NpgsqlTransaction transaction,
    Guid owner,
    LocalDemoCatalogOptions localDemo) : INutritionSession
{
    private readonly NutritionCatalogReader _catalog = new(connection, transaction, localDemo);

    private static string Table(string kind) => kind switch
    {
        "assessment" => "nutrition.assessments",
        "recommendation" => "nutrition.recommendations",
        "plan" => "nutrition.meal_plans",
        _ => throw new ArgumentException("Invalid resource kind.")
    };
    private NpgsqlCommand Command(string sql) => new(sql, connection, transaction);
    private static NutritionResource Read(NpgsqlDataReader r) => new(r.GetGuid(0), r.GetGuid(1), r.GetGuid(2),
        r.GetInt64(3), r.GetString(4), r.GetString(5), r.GetGuid(6), r.GetString(7), r.GetFieldValue<DateTimeOffset>(8));
    private const string Columns = "id,customer_id,beneficiary_id,health_revision,status,payload::text,idempotency_key,fingerprint,created_at";
    public async Task<NutritionResource?> GetAsync(string kind, Guid beneficiary, Guid id, CancellationToken ct)
    {
        await using var c = Command($"SELECT {Columns} FROM {Table(kind)} WHERE id=@id AND customer_id=@owner AND beneficiary_id=@beneficiary FOR UPDATE");
        c.Parameters.AddWithValue("id", id); c.Parameters.AddWithValue("owner", owner); c.Parameters.AddWithValue("beneficiary", beneficiary);
        await using var r = await c.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? Read(r) : null;
    }
    public async Task<NutritionResource?> FindByKeyAsync(string kind, Guid key, CancellationToken ct)
    {
        await using var c = Command($"SELECT {Columns} FROM {Table(kind)} WHERE customer_id=@owner AND idempotency_key=@key");
        c.Parameters.AddWithValue("owner", owner); c.Parameters.AddWithValue("key", key);
        await using var r = await c.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? Read(r) : null;
    }
    public async Task InsertAsync(string kind, NutritionResource value, CancellationToken ct)
    {
        await using var c = Command($"INSERT INTO {Table(kind)} (id,customer_id,beneficiary_id,health_revision,status,payload,idempotency_key,fingerprint) VALUES (@id,@owner,@beneficiary,@revision,@status,@payload::jsonb,@key,@fingerprint)");
        Bind(c, value); await c.ExecuteNonQueryAsync(ct);
        if (kind == "assessment")
        {
            await using var job = Command("INSERT INTO nutrition.assessment_jobs(assessment_id,customer_id,beneficiary_id) VALUES (@id,@owner,@beneficiary)");
            job.Parameters.AddWithValue("id", value.Id); job.Parameters.AddWithValue("owner", owner); job.Parameters.AddWithValue("beneficiary", value.BeneficiaryId);
            await job.ExecuteNonQueryAsync(ct);
        }
    }
    public async Task<bool> UpdateAsync(string kind, NutritionResource value, Guid? leaseToken, CancellationToken ct)
    {
        var fence = leaseToken is null ? "" : " AND EXISTS(SELECT 1 FROM nutrition.assessment_jobs j WHERE j.assessment_id=@id AND j.lease_token=@token AND j.lease_until>now())";
        await using var c = Command($"UPDATE {Table(kind)} SET status=@status,payload=@payload::jsonb,updated_at=now() WHERE id=@id AND customer_id=@owner AND beneficiary_id=@beneficiary{fence}");
        Bind(c, value); if (leaseToken is { } token) c.Parameters.AddWithValue("token", token);
        var updated = await c.ExecuteNonQueryAsync(ct) == 1;
        if (updated && kind == "assessment" && value.Status is not ("queued" or "processing"))
        {
            await using var job = Command("DELETE FROM nutrition.assessment_jobs WHERE assessment_id=@id" + (leaseToken is null ? "" : " AND lease_token=@token"));
            job.Parameters.AddWithValue("id", value.Id); if (leaseToken is { } t) job.Parameters.AddWithValue("token", t);
            await job.ExecuteNonQueryAsync(ct);
        }
        return updated;
    }
    private void Bind(NpgsqlCommand c, NutritionResource v)
    {
        c.Parameters.AddWithValue("id", v.Id); c.Parameters.AddWithValue("owner", owner); c.Parameters.AddWithValue("beneficiary", v.BeneficiaryId);
        c.Parameters.AddWithValue("revision", v.HealthRevision); c.Parameters.AddWithValue("status", v.Status); c.Parameters.AddWithValue("payload", v.Payload);
        c.Parameters.AddWithValue("key", v.IdempotencyKey); c.Parameters.AddWithValue("fingerprint", v.Fingerprint);
    }
    public async Task<int> AssessmentCountAsync(CancellationToken ct)
    {
        await using var c = Command("SELECT count(*)::int FROM nutrition.assessments WHERE customer_id=@owner AND created_at>now()-interval '24 hours'");
        c.Parameters.AddWithValue("owner", owner); return (int)(await c.ExecuteScalarAsync(ct))!;
    }
    public async Task<IReadOnlyList<NutritionResource>> PlansAsync(Guid beneficiary, CancellationToken ct)
    {
        await using var c = Command($"SELECT {Columns} FROM nutrition.meal_plans WHERE customer_id=@owner AND beneficiary_id=@beneficiary ORDER BY created_at DESC LIMIT 20");
        c.Parameters.AddWithValue("owner", owner); c.Parameters.AddWithValue("beneficiary", beneficiary);
        await using var r = await c.ExecuteReaderAsync(ct); var results = new List<NutritionResource>();
        while (await r.ReadAsync(ct)) results.Add(Read(r)); return results;
    }
    public Task<IReadOnlyList<NutritionConcept>> ConceptsAsync(CancellationToken ct) => _catalog.ConceptsAsync(ct);
    public Task<long> CatalogRevisionAsync(CancellationToken ct) => _catalog.CatalogRevisionAsync(ct);
    public Task<IReadOnlyList<Recipe>> RecipesAsync(CancellationToken ct) => _catalog.RecipesAsync(ct);
    public Task<IReadOnlyList<DietaryRule>> RulesAsync(CancellationToken ct) => _catalog.RulesAsync(ct);
}
