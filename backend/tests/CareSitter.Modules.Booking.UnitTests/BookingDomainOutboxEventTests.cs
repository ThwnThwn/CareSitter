using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Domain.Events;
using BookingAggregate = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingDomainOutboxEventTests
{
    [Fact]
    public void Status_transition_is_serialized_as_pending_outbox_event()
    {
        var booking = BookingAggregate.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            DateTimeOffset.UtcNow.AddDays(1), DateTimeOffset.UtcNow.AddDays(1).AddHours(2)).Value;
        Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
        var domainEvent = Assert.IsType<BookingStatusChanged>(Assert.Single(booking.DomainEvents));

        var outbox = BookingDomainOutboxEvent.From(domainEvent, bookingVersion: 2);

        Assert.Equal(domainEvent.EventId, outbox.EventId);
        Assert.Equal(booking.Id, outbox.BookingId);
        Assert.Equal(2, outbox.BookingVersion);
        Assert.Equal(nameof(BookingStatusChanged), outbox.EventType);
        Assert.Contains("\"From\":\"Draft\"", outbox.Payload, StringComparison.Ordinal);
        Assert.Contains("\"To\":\"PendingPayment\"", outbox.Payload, StringComparison.Ordinal);
        Assert.Equal("PENDING", outbox.Status);
    }

    [Fact]
    public void Failed_delivery_is_retryable_then_dead_lettered()
    {
        var domainEvent = new BookingSosRaised(Guid.NewGuid(), Guid.NewGuid());
        var outbox = BookingDomainOutboxEvent.From(domainEvent, bookingVersion: 3);
        var now = DateTimeOffset.UtcNow;

        outbox.Claim(Guid.NewGuid(), now, now.AddSeconds(30));
        outbox.MarkFailed("temporary", now.AddSeconds(5), now, deadLetter: false);
        Assert.Equal("FAILED", outbox.Status);

        outbox.Claim(Guid.NewGuid(), now.AddSeconds(5), now.AddSeconds(35));
        outbox.MarkFailed("permanent", now.AddSeconds(10), now.AddSeconds(5), deadLetter: true);
        Assert.Equal("DEAD_LETTER", outbox.Status);
        Assert.Equal(2, outbox.Attempts);
    }
}
