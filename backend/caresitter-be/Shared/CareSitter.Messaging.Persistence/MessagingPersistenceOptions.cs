using Microsoft.Extensions.Configuration;

namespace CareSitter.Messaging.Persistence;

/// <summary>Environment-only polling, lease and retention settings, independent of the transport client.</summary>
public sealed record MessagingPersistenceOptions(int BatchSize, int PollIntervalMs, int LeaseSeconds,
    int OutboxRetentionDays, int InboxRetentionDays)
{
    /// <summary>Validates settings, including enough lease time for one acknowledged publish.</summary>
    public static MessagingPersistenceOptions Read(IConfiguration c)
    {
        int Read(string key, int fallback) => c[key] is not { } text ? fallback : int.TryParse(text, out var n) ? n :
            throw new InvalidOperationException($"{key} must be an integer.");
        var o = new MessagingPersistenceOptions(Read("KAFKA_OUTBOX_BATCH_SIZE", 20), Read("KAFKA_OUTBOX_POLL_INTERVAL_MS", 2000),
            Read("KAFKA_OUTBOX_LEASE_SECONDS", 60), Read("KAFKA_OUTBOX_RETENTION_DAYS", 7), Read("KAFKA_INBOX_RETENTION_DAYS", 14));
        if (o.BatchSize is < 1 or > 100 || o.PollIntervalMs is < 100 or > 60000 || o.LeaseSeconds is < 5 or > 3600)
            throw new InvalidOperationException("KAFKA_OUTBOX_BATCH_SIZE, KAFKA_OUTBOX_POLL_INTERVAL_MS or KAFKA_OUTBOX_LEASE_SECONDS is out of range.");
        if (o.LeaseSeconds * 1000L <= Read("KAFKA_PRODUCER_DELIVERY_TIMEOUT_MS", 10000) + 5000)
            throw new InvalidOperationException("KAFKA_OUTBOX_LEASE_SECONDS must exceed delivery timeout by more than 5 seconds.");
        if (o.OutboxRetentionDays < 1 || o.InboxRetentionDays <= 7)
            throw new InvalidOperationException("KAFKA_OUTBOX_RETENTION_DAYS must be positive; KAFKA_INBOX_RETENTION_DAYS must exceed the 7-day topic retention.");
        return o;
    }
}
