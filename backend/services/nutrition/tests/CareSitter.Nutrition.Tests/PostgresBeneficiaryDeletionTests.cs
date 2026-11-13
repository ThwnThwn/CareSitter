using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed partial class PostgresWorkflowTests
{
    [PostgresFact]
    public async Task Beneficiary_deletion_purges_only_target_and_blocks_recreation()
    {
        var target = Guid.NewGuid();
        var other = Guid.NewGuid();
        await _store.InOwnerScopeAsync(_owner, async session =>
        {
            foreach (var beneficiary in new[] { target, other })
            {
                foreach (var kind in new[] { "assessment", "recommendation", "plan" })
                    await session.InsertAsync(kind, new NutritionResource(Guid.NewGuid(), _owner, beneficiary,
                        1, "queued", "{}", Guid.NewGuid(), "fixture", DateTimeOffset.UtcNow), default);
            }
            return true;
        }, default);
        var processor = new BeneficiaryDeletionProcessor(_dataSource);
        var eventId = Guid.NewGuid();
        var deleted = new BeneficiaryDeletionProcessor.BeneficiaryDeleted(_owner, target, DateTimeOffset.UtcNow);
        await processor.PurgeAsync(eventId, deleted, default);
        await processor.PurgeAsync(eventId, deleted, default);
        await using var db = await _dataSource.OpenConnectionAsync();
        await using var transaction = await db.BeginTransactionAsync();
        await using (var scope = new NpgsqlCommand("SELECT set_config('app.current_user_id',@owner::text,true)", db, transaction))
        {
            scope.Parameters.AddWithValue("owner", _owner);
            await scope.ExecuteNonQueryAsync();
        }
        foreach (var table in new[] { "assessments", "assessment_jobs", "recommendations", "meal_plans" })
        {
            await using var count = new NpgsqlCommand($"SELECT count(*) FROM nutrition.{table} WHERE customer_id=@owner AND beneficiary_id=@beneficiary", db, transaction);
            count.Parameters.AddWithValue("owner", _owner);
            count.Parameters.AddWithValue("beneficiary", target);
            Assert.Equal(0L, await count.ExecuteScalarAsync());
            count.Parameters["beneficiary"].Value = other;
            Assert.Equal(1L, await count.ExecuteScalarAsync());
        }
        await transaction.CommitAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => _store.InOwnerScopeAsync(_owner, async session =>
        {
            await session.InsertAsync("assessment", new NutritionResource(Guid.NewGuid(), _owner, target,
                1, "queued", "{}", Guid.NewGuid(), "fixture", DateTimeOffset.UtcNow), default);
            return true;
        }, default));
    }
}
