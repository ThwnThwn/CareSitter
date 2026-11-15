using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Messaging.Persistence.Outbox;

/// <summary>Stages outbox records in exactly the caller's DbContext; it never saves independently.</summary>
public sealed class OutboxWriter<TDbContext>(TDbContext db, IEventSerializer serializer) : IOutboxWriter where TDbContext : DbContext
{
    /// <summary>Validates and stages the entire immutable envelope before the business transaction commits.</summary>
    public void Add(EventEnvelope envelope)
    {
        db.Set<KafkaOutboxMessage>().Add(new()
        {
            Id = envelope.EventId, EventType = envelope.EventType, SchemaVersion = envelope.SchemaVersion,
            Topic = serializer.GetTopic(envelope), MessageKey = envelope.Key, Envelope = serializer.Serialize(envelope),
            CorrelationId = envelope.CorrelationId, OccurredAt = envelope.OccurredAt, NextAttemptAt = DateTimeOffset.UtcNow
        });
    }
}
