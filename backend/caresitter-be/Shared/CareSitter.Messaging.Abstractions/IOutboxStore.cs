using CareSitter.Messaging.Contracts;

namespace CareSitter.Messaging.Abstractions;

/// <summary>A scoped adapter for one module-owned outbox.</summary>
public interface IOutboxStore
{
    string Name { get; }
    /// <summary>Atomically claims available records using an expiring owner lease.</summary>
    Task<IReadOnlyList<OutboxDelivery>> ClaimAsync(string owner, int batchSize, TimeSpan lease, CancellationToken ct);
    /// <summary>Renews ownership before publishing a record from a claimed batch.</summary>
    Task<bool> RenewAsync(Guid id, string owner, TimeSpan lease, CancellationToken ct);
    /// <summary>Marks acknowledgement only if the calling relay still owns the record.</summary>
    Task MarkPublishedAsync(Guid id, string owner, CancellationToken ct);
    /// <summary>Releases the lease and schedules a bounded retry.</summary>
    Task MarkFailedAsync(Guid id, string owner, string error, TimeSpan delay, CancellationToken ct);
    /// <summary>Deletes acknowledged records only; unresolved records are retained.</summary>
    Task<int> DeletePublishedAsync(DateTimeOffset before, CancellationToken ct);
    /// <summary>Reports pending volume and oldest occurrence for monitoring.</summary>
    Task<OutboxStatistics> GetStatisticsAsync(CancellationToken ct);
}

/// <summary>A claimed immutable envelope and its persistent delivery attempt count.</summary>
public sealed record OutboxDelivery(Guid Id, string EnvelopeJson, int AttemptCount);
/// <summary>The current backlog in one outbox.</summary>
public sealed record OutboxStatistics(long Pending, DateTimeOffset? Oldest);
