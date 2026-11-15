using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingMealPolicyTests
{
    [Fact]
    public void Meal_date_uses_vietnam_timezone_and_exclusive_shift_end()
    {
        var start = DateTimeOffset.Parse("2026-11-14T16:00:00Z");
        var booking = Domain.Booking.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), start, start.AddHours(1)).Value;
        Assert.True(BookingMealPolicy.CoversDate(booking, new DateOnly(2026, 11, 14)));
        Assert.False(BookingMealPolicy.CoversDate(booking, new DateOnly(2026, 11, 15)));
    }
    [Theory]
    [InlineData(BookingStatus.PendingPayment, false)]
    [InlineData(BookingStatus.Confirmed, false)]
    [InlineData(BookingStatus.CaregiverAccepted, true)]
    [InlineData(BookingStatus.InProgress, true)]
    [InlineData(BookingStatus.Completed, false)]
    [InlineData(BookingStatus.Cancelled, false)]
    public void Offers_and_closed_shifts_do_not_grant_caregiver_meal_access(BookingStatus status, bool allowed) =>
        Assert.Equal(allowed, BookingMealPolicy.CanCaregiverRead(status));
}
