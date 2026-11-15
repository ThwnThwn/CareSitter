using CareSitter.SharedKernel.Domain;

namespace CareSitter.Modules.Booking.Domain.Events;

public abstract record BookingDomainEvent : IDomainEvent
{
    public Guid EventId { get; } = Guid.NewGuid();
    public DateTimeOffset OccurredOnUtc { get; } = DateTimeOffset.UtcNow;
}

public sealed record BookingStatusChanged(Guid BookingId, BookingStatus From, BookingStatus To)
    : BookingDomainEvent;

public sealed record BookingCheckedIn(Guid BookingId, Guid CaregiverId, double DistanceMeters)
    : BookingDomainEvent;

public sealed record BookingCompletedDomainEvent(Guid BookingId, Guid CaregiverId, long EscrowAmount)
    : BookingDomainEvent;

public sealed record BookingSosRaised(Guid BookingId, Guid? RaisedByUserId) : BookingDomainEvent;
