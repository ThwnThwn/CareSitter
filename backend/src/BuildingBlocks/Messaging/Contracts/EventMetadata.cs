namespace CareSitter.Messaging.Contracts;

/// <summary>Metadata supplied by the owning application when it creates a durable event.</summary>
public sealed record EventMetadata(Guid EventId, DateTimeOffset OccurredAt, string Producer,
    string Key, string? CorrelationId = null);
