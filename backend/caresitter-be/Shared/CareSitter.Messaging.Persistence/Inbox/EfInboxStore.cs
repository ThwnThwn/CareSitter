using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Messaging.Persistence.Inbox;

// Schema identifiers are allowlisted by ValidateSchema; every data value remains parameterized.
#pragma warning disable EF1002

/// <summary>Atomically deduplicates local effects using the same DbContext as the application handler.</summary>
public sealed class EfInboxStore<TDbContext> : IInboxStore where TDbContext : DbContext
{
    private readonly TDbContext _db;
    private readonly string _table;

    /// <summary>Binds inbox markers and business writes to the owning module context.</summary>
    public EfInboxStore(TDbContext db, string schema)
    {
        OutboxConfiguration.ValidateSchema(schema);
        _db = db;
        _table = $"\"{schema}\".kafka_inbox_messages";
    }

    /// <summary>Rolls back both the marker and business changes on rejection, exception or cancellation.</summary>
    public async Task<HandlerResult> ExecuteAsync(EventContext context, string handlerName,
        Func<CancellationToken, Task<HandlerResult>> action, CancellationToken ct)
    {
        if (_db.Database.CurrentTransaction is not null)
            throw new InvalidOperationException("Inbox execution must own the transaction boundary.");
        await using var tx = await _db.Database.BeginTransactionAsync(ct);
        try
        {
            var inserted = await _db.Database.ExecuteSqlRawAsync($"INSERT INTO {_table} (consumer_name, handler_name, event_id, event_type, processed_at) VALUES ({{0}}, {{1}}, {{2}}, {{3}}, now()) ON CONFLICT DO NOTHING",
                [context.ConsumerName, handlerName, context.EventId, context.EventType], ct);
            if (inserted == 0) { await tx.CommitAsync(ct); return HandlerResult.Success(); }
            var result = await action(ct);
            if (result.Outcome != HandlerOutcome.Success)
            {
                await tx.RollbackAsync(ct);
                _db.ChangeTracker.Clear();
                return result;
            }
            await _db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return result;
        }
        catch
        {
            await tx.RollbackAsync(CancellationToken.None);
            _db.ChangeTracker.Clear();
            throw;
        }
    }

    /// <summary>Deletes inbox records only after the configured deduplication/replay window expires.</summary>
    public Task<int> DeleteProcessedAsync(DateTimeOffset before, CancellationToken ct) =>
        _db.Set<InboxMessage>().Where(x => x.ProcessedAt < before).ExecuteDeleteAsync(ct);
}
