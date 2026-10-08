namespace CareSitter.Messaging.Abstractions;

/// <summary>Transport metadata available to a handler without referencing a Kafka client.</summary>
public sealed record EventContext(Guid EventId, string EventType, int SchemaVersion,
    string ConsumerName, string Topic, int Partition, long Offset, string? CorrelationId);
