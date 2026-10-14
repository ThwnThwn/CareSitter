using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.ValueObjects;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingLifecyclePolicyTests
{
    [Theory]
    [InlineData(1)]
    [InlineData(48)]
    [InlineData(720)]
    public void Settlement_waits_for_the_bookings_configured_dispute_window_and_is_released_once(int hours)
    {
        var booking = CheckedIn();
        Assert.True(booking.ApplyPricing(100000, 15000, 85000, disputeWindowHours: hours).IsSuccess);
        Assert.True(booking.RequestManualCheckout().IsSuccess);
        Assert.True(booking.Complete().IsSuccess);
        var matureAt = booking.ActualEnd!.Value.AddHours(hours);
        Assert.False(BookingLifecyclePolicy.IsSettlementMature(booking, matureAt.AddTicks(-1)));
        Assert.True(BookingLifecyclePolicy.IsSettlementMature(booking, matureAt));
        Assert.True(booking.MarkSettlementReleased(matureAt).IsSuccess);
        Assert.False(BookingLifecyclePolicy.IsSettlementMature(booking, matureAt.AddDays(1)));
    }

    [Fact]
    public void Elapsed_schedule_and_timeout_checkout_do_not_make_a_settlement_mature()
    {
        var booking = CheckedIn();
        Assert.False(BookingLifecyclePolicy.IsSettlementMature(booking, DateTimeOffset.UtcNow.AddDays(100)));
        Assert.True(booking.RequestSystemTimeoutCheckout(DateTimeOffset.UtcNow).IsSuccess);
        Assert.False(BookingLifecyclePolicy.IsSettlementMature(booking, DateTimeOffset.UtcNow.AddDays(100)));
    }

    private static BookingEntity CheckedIn()
    {
        var now = DateTimeOffset.UtcNow;
        var booking = BookingEntity.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            now.AddHours(-2), now.AddHours(-1)).Value;
        Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
        Assert.True(booking.ConfirmPayment().IsSuccess);
        Assert.True(booking.AssignCaregiver(Guid.NewGuid()).IsSuccess);
        Assert.True(booking.StartEnRoute().IsSuccess);
        var point = new GeoPoint(10.77, 106.69);
        Assert.True(booking.CheckIn(point, point, checkedInAt: now.AddHours(-2)).IsSuccess);
        return booking;
    }
}
