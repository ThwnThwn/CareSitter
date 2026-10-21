using CareSitter.Nutrition.Application;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionStore(NpgsqlDataSource dataSource, LocalDemoCatalogOptions localDemo) : INutritionStore
{
    internal NutritionStore(NpgsqlDataSource dataSource) : this(dataSource, LocalDemoCatalogOptions.Disabled) { }

    public async Task<T> InOwnerScopeAsync<T>(Guid owner, Func<INutritionSession, Task<T>> action, CancellationToken ct)
    {
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        // Owner lock serializes quota and same-key creation; no network/AI while held.
        await using (var scope = new NpgsqlCommand("SELECT set_config('app.current_user_id',@owner::text,true); SELECT pg_advisory_xact_lock(hashtextextended('nutrition:' || @owner::text,0))", connection, transaction))
        {
            scope.Parameters.AddWithValue("owner", owner);
            await scope.ExecuteNonQueryAsync(ct);
        }
        var result = await action(new NutritionSession(connection, transaction, owner, localDemo));
        await transaction.CommitAsync(ct);
        return result;
    }

    public async Task<(Guid Owner, Guid Beneficiary, Guid Id, Guid Token, int Attempts)?> ClaimAsync(CancellationToken ct)
    {
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var command = new NpgsqlCommand("""
            UPDATE nutrition.assessment_jobs SET lease_token=@token,
              lease_until=now()+interval '60 seconds', attempt_count=attempt_count+1
            WHERE assessment_id=(SELECT assessment_id FROM nutrition.assessment_jobs
              WHERE lease_until IS NULL OR lease_until < now() ORDER BY created_at
              FOR UPDATE SKIP LOCKED LIMIT 1)
            RETURNING customer_id,beneficiary_id,assessment_id,lease_token,attempt_count
            """, connection);
        command.Parameters.AddWithValue("token", Guid.NewGuid());
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? (reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2), reader.GetGuid(3), reader.GetInt32(4)) : null;
    }

}
