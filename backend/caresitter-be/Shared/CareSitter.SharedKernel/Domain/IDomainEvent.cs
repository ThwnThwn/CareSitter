using MediatR;

namespace CareSitter.SharedKernel.Domain;

/// <summary>
/// Su kien domain trong cung 1 module. Phat qua MediatR INotification, ghi Outbox khi can lan ra module khac.
/// </summary>
public interface IDomainEvent : INotification
{
    Guid EventId { get; }
    DateTimeOffset OccurredOnUtc { get; }
}
