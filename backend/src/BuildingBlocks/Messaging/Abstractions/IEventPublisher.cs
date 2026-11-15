using CareSitter.Messaging.Contracts;

namespace CareSitter.Messaging.Abstractions;

/// <summary>Publishes an existing envelope and reports broker acknowledgement.</summary>
public interface IEventPublisher
{
    /// <summary>Returns only after acknowledgement; failures leave durable outbox state pending.</summary>
    Task<PublishResult> PublishAsync(EventEnvelope envelope, CancellationToken ct = default);
}

/// <summary>The broker position assigned to an acknowledged message.</summary>
public sealed record PublishResult(Guid EventId, string Topic, int Partition, long Offset);
