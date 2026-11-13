using CareSitter.Nutrition.Application;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionStore(NpgsqlDataSource dataSource, RecommendationLockDataSource lockDataSource, LocalDemoCatalogOptions localDemo, Microsoft.Extensions.Options.IOptions<MealGroundingOptions>? grounding = null) : INutritionStore
{
    internal NutritionStore(NpgsqlDataSource dataSource, RecommendationLockDataSource lockDataSource) : this(dataSource, lockDataSource, LocalDemoCatalogOptions.Disabled) { }

    public async Task<T> InRecommendationScopeAsync<T>(Guid owner, Guid key, Func<Task<T>> action, CancellationToken ct)
    {
        // Coalesce ranking across service instances without holding an owner transaction during AI.
        // Resource uniqueness remains enforced by UNIQUE(customer_id,idempotency_key).
        // Use a distinct pool: a held request lock must not consume the last owner-transaction connection.
        // Losers release their connection while waiting so they cannot exhaust the transaction pool.
        const string lockKey = "hashtextextended('nutrition-request:' || @owner::text || ':' || @key::text,0)";
        while (true)
        {
            ct.ThrowIfCancellationRequested();
            await using (var connection = await lockDataSource.OpenConnectionAsync(ct))
            {
                await using var acquire = new NpgsqlCommand($"SELECT pg_try_advisory_lock({lockKey})", connection);
                acquire.Parameters.AddWithValue("owner", owner);
                acquire.Parameters.AddWithValue("key", key);
                bool acquired;
                try { acquired = (bool)(await acquire.ExecuteScalarAsync(ct))!; }
                catch
                {
                    // The server may have acquired the session lock before cancellation or
                    // transport failure prevented us from receiving its result.
                    NpgsqlConnection.ClearPool(connection);
                    throw;
                }
                if (acquired)
                {
                    try { return await action(); }
                    finally
                    {
                        await using var release = new NpgsqlCommand($"SELECT pg_advisory_unlock({lockKey})", connection);
                        release.CommandTimeout = 5;
                        release.Parameters.AddWithValue("owner", owner);
                        release.Parameters.AddWithValue("key", key);
                        try { await release.ExecuteScalarAsync(CancellationToken.None); }
                        catch
                        {
                            // Pool reset can be deferred until reuse. Close this physical session
                            // instead of returning a possibly locked session to an idle pool.
                            NpgsqlConnection.ClearPool(connection);
                            throw;
                        }
                    }
                }
            }
            await Task.Delay(TimeSpan.FromMilliseconds(50), ct);
        }
    }

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
        var result = await action(new NutritionSession(connection, transaction, owner, localDemo, grounding?.Value.AllowNonMedicalReference ?? false));
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
