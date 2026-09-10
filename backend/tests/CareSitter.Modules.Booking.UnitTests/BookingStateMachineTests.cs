using CareSitter.Modules.Booking.Domain;
using Xunit;

namespace CareSitter.Modules.Booking.UnitTests;

public class BookingStateMachineTests
{
    [Theory]
    [InlineData(BookingStatus.Draft, BookingStatus.PendingPayment, true)]
    [InlineData(BookingStatus.Draft, BookingStatus.Cancelled, true)]
    [InlineData(BookingStatus.PendingPayment, BookingStatus.Confirmed, true)]
    [InlineData(BookingStatus.Confirmed, BookingStatus.MatchingFailed, true)]
    [InlineData(BookingStatus.Confirmed, BookingStatus.CaregiverAccepted, true)]
    [InlineData(BookingStatus.MatchingFailed, BookingStatus.Cancelled, true)]
    [InlineData(BookingStatus.CaregiverAccepted, BookingStatus.CaregiverEnRoute, true)]
    [InlineData(BookingStatus.CaregiverEnRoute, BookingStatus.InProgress, true)]
    [InlineData(BookingStatus.InProgress, BookingStatus.Completed, false)]
    [InlineData(BookingStatus.InProgress, BookingStatus.CheckoutPendingReview, true)]
    [InlineData(BookingStatus.InProgress, BookingStatus.Crisis, true)]
    [InlineData(BookingStatus.Draft, BookingStatus.Completed, false)]
    [InlineData(BookingStatus.Cancelled, BookingStatus.Confirmed, false)]
    [InlineData(BookingStatus.MatchingFailed, BookingStatus.CaregiverAccepted, false)]
    [InlineData(BookingStatus.Completed, BookingStatus.PendingPayment, false)]
    public void CanTransition_ShouldValidateStateTransitionsCorrectly(BookingStatus from, BookingStatus to, bool expected)
    {
        // Act
        bool result = BookingStateMachine.CanTransition(from, to);

        // Assert
        Assert.Equal(expected, result);
    }
}
