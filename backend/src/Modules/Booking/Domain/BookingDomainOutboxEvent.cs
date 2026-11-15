using CareSitter.Modules.Booking.Domain.Events;
using CareSitter.SharedKernel.Domain;
using System.Text.Json;

namespace CareSitter.Modules.Booking.Domain;

public sealed class BookingDomainOutboxEvent
{
    private BookingDomainOutboxEvent() { }

    private BookingDomainOutboxEvent(
        Guid eventId,
        Guid bookingId,
        long bookingVersion,
        string eventType,
        string payload,
        DateTimeOffset occurredAt)
    {
        EventId = eventId;
        BookingId = bookingId;
        BookingVersion = bookingVersion;
        EventType = eventType;
        Payload = payload;
        OccurredAt = occurredAt;
        Status = "PENDING";
        AvailableAt = occurredAt;
        CreatedAt = occurredAt;
        UpdatedAt = occurredAt;
    }

    public Guid EventId { get; private set; }
    public Guid BookingId { get; private set; }
    public long BookingVersion { get; private set; }
    public string EventType { get; private set; } = string.Empty;
    public string Payload { get; private set; } = "{}";
    public DateTimeOffset OccurredAt { get; private set; }
    public string Status { get; private set; } = string.Empty;
    public int Attempts { get; private set; }
    public DateTimeOffset AvailableAt { get; private set; }
    public DateTimeOffset? LeaseUntil { get; private set; }
    public Guid? ClaimToken { get; private set; }
    public string? LastError { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }
    public DateTimeOffset? ProcessedAt { get; private set; }

    public static BookingDomainOutboxEvent From(IDomainEvent domainEvent, long bookingVersion) =>
        domainEvent switch
        {
            BookingStatusChanged value => new(value.EventId, value.BookingId, bookingVersion,
                nameof(BookingStatusChanged), JsonSerializer.Serialize(new
                {
                    From = value.From.ToString(),
                    To = value.To.ToString()
                }), value.OccurredOnUtc),
            BookingCheckedIn value => new(value.EventId, value.BookingId, bookingVersion,
                nameof(BookingCheckedIn), JsonSerializer.Serialize(new
                {
                    value.CaregiverId,
                    value.DistanceMeters
                }), value.OccurredOnUtc),
            BookingCompletedDomainEvent value => new(value.EventId, value.BookingId, bookingVersion,
                nameof(BookingCompletedDomainEvent), JsonSerializer.Serialize(new
                {
                    value.CaregiverId,
                    value.EscrowAmount
                }), value.OccurredOnUtc),
            BookingSosRaised value => new(value.EventId, value.BookingId, bookingVersion,
                nameof(BookingSosRaised), JsonSerializer.Serialize(new
                {
                    value.RaisedByUserId
                }), value.OccurredOnUtc),
            _ => throw new InvalidOperationException(
                $"Unsupported booking domain event '{domainEvent.GetType().Name}'.")
        };

    public void Claim(Guid claimToken, DateTimeOffset now, DateTimeOffset leaseUntil)
    {
        Status = "PROCESSING";
        ClaimToken = claimToken;
        LeaseUntil = leaseUntil;
        Attempts++;
        UpdatedAt = now;
    }

    public void MarkProcessed(DateTimeOffset now)
    {
        Status = "PROCESSED";
        ClaimToken = null;
        LeaseUntil = null;
        LastError = null;
        ProcessedAt = now;
        UpdatedAt = now;
    }

    public void MarkFailed(string error, DateTimeOffset availableAt, DateTimeOffset now, bool deadLetter)
    {
        Status = deadLetter ? "DEAD_LETTER" : "FAILED";
        ClaimToken = null;
        LeaseUntil = null;
        LastError = error.Length <= 500 ? error : error[..500];
        AvailableAt = availableAt;
        UpdatedAt = now;
    }
}
