using CareSitter.Messaging.Abstractions;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Messaging.Persistence.Outbox;

// Schema identifiers are allowlisted by ValidateSchema; every data value remains parameterized.
#pragma warning disable EF1002

/// <summary>A PostgreSQL outbox adapter with atomic claims and owner-fenced completion updates.</summary>
public sealed class EfOutboxStore<TDbContext> : IOutboxStore where TDbContext : DbContext
{
    private readonly TDbContext _db;
    private readonly string _table;
    public string Name { get; }

    /// <summary>Binds the store to one module context and an allowlisted schema identifier.</summary>
    public EfOutboxStore(TDbContext db, string schema)
    {
        OutboxConfiguration.ValidateSchema(schema);
        _db = db;
        Name = schema;
        _table = $"\"{schema}\".kafka_outbox_messages";
    }

    /// <summary>Claims due records without waiting for another relay's locked rows.</summary>
    public async Task<IReadOnlyList<OutboxDelivery>> ClaimAsync(string owner, int batchSize, TimeSpan lease, CancellationToken ct)
    {
        var rows = await _db.Set<KafkaOutboxMessage>().FromSqlRaw($$"""
            UPDATE {{_table}} SET lease_owner = {0}, lease_until = now() + ({1} * interval '1 second'),
                attempt_count = attempt_count + 1
            WHERE id IN (SELECT id FROM {{_table}}
                WHERE published_at IS NULL AND next_attempt_at <= now()
                AND (lease_until IS NULL OR lease_until < now())
                ORDER BY occurred_at, id LIMIT {2} FOR UPDATE SKIP LOCKED)
            RETURNING *
            """, owner, (int)lease.TotalSeconds, batchSize).AsNoTracking().ToListAsync(ct);
        return rows.OrderBy(x => x.OccurredAt).ThenBy(x => x.Id)
            .Select(x => new OutboxDelivery(x.Id, x.Envelope, x.AttemptCount)).ToArray();
    }

    /// <summary>Renews only a live lease before publishing; stale owners must skip the record.</summary>
    public async Task<bool> RenewAsync(Guid id, string owner, TimeSpan lease, CancellationToken ct) =>
        await _db.Database.ExecuteSqlRawAsync($"UPDATE {_table} SET lease_until = now() + ({{0}} * interval '1 second') WHERE id = {{1}} AND lease_owner = {{2}} AND lease_until > now() AND published_at IS NULL",
            [(int)lease.TotalSeconds, id, owner], ct) == 1;

    /// <summary>Fences a stale relay from marking a record owned by a replacement relay.</summary>
    public async Task MarkPublishedAsync(Guid id, string owner, CancellationToken ct) =>
        await _db.Database.ExecuteSqlRawAsync($"UPDATE {_table} SET published_at = now(), lease_owner = NULL, lease_until = NULL, last_error = NULL WHERE id = {{0}} AND lease_owner = {{1}}",
            [id, owner], ct);

    /// <summary>Persists a safe failure classification and schedules redelivery with the same envelope.</summary>
    public async Task MarkFailedAsync(Guid id, string owner, string error, TimeSpan delay, CancellationToken ct) =>
        await _db.Database.ExecuteSqlRawAsync($"UPDATE {_table} SET next_attempt_at = now() + ({{0}} * interval '1 millisecond'), last_error = {{1}}, lease_owner = NULL, lease_until = NULL WHERE id = {{2}} AND lease_owner = {{3}}",
            [(int)delay.TotalMilliseconds, error[..Math.Min(error.Length, 512)], id, owner], ct);

    /// <summary>Removes completed records only, preserving unresolved failures for investigation.</summary>
    public Task<int> DeletePublishedAsync(DateTimeOffset before, CancellationToken ct) =>
        _db.Set<KafkaOutboxMessage>().Where(x => x.PublishedAt < before).ExecuteDeleteAsync(ct);

    /// <summary>Reads a bounded-cardinality backlog summary for this module.</summary>
    public async Task<OutboxStatistics> GetStatisticsAsync(CancellationToken ct)
    {
        var query = _db.Set<KafkaOutboxMessage>().Where(x => x.PublishedAt == null);
        return new(await query.LongCountAsync(ct), await query.MinAsync(x => (DateTimeOffset?)x.OccurredAt, ct));
    }
}
