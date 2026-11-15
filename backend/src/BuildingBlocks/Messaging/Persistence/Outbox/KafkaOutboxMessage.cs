namespace CareSitter.Messaging.Persistence.Outbox;

/// <summary>A module-owned immutable wire envelope with independent Kafka delivery state.</summary>
public sealed class KafkaOutboxMessage
{
    public Guid Id { get; set; }
    public string EventType { get; set; } = "";
    public int SchemaVersion { get; set; }
    public string Topic { get; set; } = "";
    public string MessageKey { get; set; } = "";
    public string Envelope { get; set; } = "";
    public string? CorrelationId { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset? PublishedAt { get; set; }
    public int AttemptCount { get; set; }
    public DateTimeOffset NextAttemptAt { get; set; }
    public string? LastError { get; set; }
    public string? LeaseOwner { get; set; }
    public DateTimeOffset? LeaseUntil { get; set; }
}
