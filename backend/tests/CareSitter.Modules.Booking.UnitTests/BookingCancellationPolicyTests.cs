using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingCancellationPolicyTests
{
    [Fact]
    public void Paid_booking_cancelled_before_start_refunds_customer_payment()
    {
        var booking = PaidBooking(DateTimeOffset.UtcNow.AddHours(2));

        var result = BookingCancellationPolicy.Evaluate(
            booking, booking.ScheduledStart.AddMinutes(-15));

        Assert.True(result.IsSuccess);
        Assert.Equal(80_000, result.Value.RefundAmount);
    }

    [Fact]
    public void Assigned_caregiver_after_start_requires_dispute()
    {
        var booking = PaidBooking(DateTimeOffset.UtcNow.AddHours(-1));
        var caregiverId = Guid.NewGuid();
        Assert.True(booking.SelectCaregiver(caregiverId).IsSuccess);
        Assert.True(booking.AssignCaregiver(caregiverId).IsSuccess);

        var result = BookingCancellationPolicy.Evaluate(
            booking, DateTimeOffset.UtcNow);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.cancel.requires_dispute", result.Error.Code);
    }

    [Fact]
    public void Matching_failure_refunds_even_after_planned_start()
    {
        var booking = PaidBooking(DateTimeOffset.UtcNow.AddHours(-1));
        Assert.True(booking.MarkMatchingFailed().IsSuccess);

        var result = BookingCancellationPolicy.Evaluate(
            booking, DateTimeOffset.UtcNow);

        Assert.True(result.IsSuccess);
        Assert.Equal(80_000, result.Value.RefundAmount);
    }

    [Fact]
    public void In_progress_service_must_be_decided_as_dispute()
    {
        var booking = PaidBooking(DateTimeOffset.UtcNow.AddHours(-1));
        var caregiverId = Guid.NewGuid();
        Assert.True(booking.SelectCaregiver(caregiverId).IsSuccess);
        Assert.True(booking.AssignCaregiver(caregiverId).IsSuccess);
        Assert.True(booking.StartEnRoute().IsSuccess);
        Assert.True(booking.TransitionTo(BookingStatus.InProgress).IsSuccess);

        var result = BookingCancellationPolicy.Evaluate(
            booking, DateTimeOffset.UtcNow);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.cancel.requires_dispute", result.Error.Code);
    }

    private static Domain.Booking PaidBooking(DateTimeOffset start)
    {
        var booking = Domain.Booking.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            start, start.AddHours(2)).Value;
        Assert.True(booking.ApplyPricing(100_000, 15_000, 85_000).IsSuccess);
        Assert.True(booking.ApplyPromotion(
            Guid.NewGuid(), "TEST20", 100_000, 20_000, 80_000, 20_000).IsSuccess);
        Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
        Assert.True(booking.ConfirmPayment().IsSuccess);
        return booking;
    }
}
