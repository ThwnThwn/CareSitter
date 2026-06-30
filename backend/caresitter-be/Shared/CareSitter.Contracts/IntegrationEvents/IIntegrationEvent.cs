using MediatR;

namespace CareSitter.Contracts.IntegrationEvents;

/// <summary>
/// Su kien lan ra giua cac module (qua Outbox). Khac IDomainEvent (trong 1 module).
/// </summary>
public interface IIntegrationEvent : INotification
{
    Guid EventId { get; }
    DateTimeOffset OccurredOnUtc { get; }
}

public abstract record IntegrationEvent : IIntegrationEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();
    public DateTimeOffset OccurredOnUtc { get; init; } = DateTimeOffset.UtcNow;
}
