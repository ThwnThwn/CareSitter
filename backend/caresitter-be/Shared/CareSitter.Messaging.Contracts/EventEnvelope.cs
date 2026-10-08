using System.Text.Json;

namespace CareSitter.Messaging.Contracts;

/// <summary>A versioned wire message. Its identity and payload remain unchanged during retries.</summary>
public sealed record EventEnvelope(Guid EventId, string EventType, int SchemaVersion,
    DateTimeOffset OccurredAt, string Producer, string? CorrelationId, string Key, JsonElement Payload);
