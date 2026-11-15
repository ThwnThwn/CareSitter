using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingMealPolicy
{
    // Lịch chăm sóc và ngày thực đơn đều dùng giờ Việt Nam, độc lập múi giờ host.
    internal static DateOnly VietnamDate(DateTimeOffset value) =>
        DateOnly.FromDateTime(value.ToOffset(TimeSpan.FromHours(7)).DateTime);
    internal static DateOnly LastDate(Domain.Booking booking) => VietnamDate(booking.ScheduledEnd.AddTicks(-1));
    internal static bool CoversDate(Domain.Booking booking, DateOnly date) =>
        date >= VietnamDate(booking.ScheduledStart) && date <= LastDate(booking);
    internal static bool CanShare(BookingStatus status) => status is BookingStatus.PendingPayment or
        BookingStatus.Confirmed or BookingStatus.CaregiverAccepted or BookingStatus.CaregiverEnRoute or BookingStatus.InProgress;
    internal static bool CanCaregiverRead(BookingStatus status) => status is BookingStatus.CaregiverAccepted or
        BookingStatus.CaregiverEnRoute or BookingStatus.InProgress or BookingStatus.CheckoutPendingReview;
    internal static bool CanRecord(Domain.Booking booking) =>
        booking.Status == BookingStatus.InProgress && booking.ActualStart is not null;
    internal static bool CanCorrect(BookingStatus status) =>
        status is BookingStatus.InProgress or BookingStatus.CheckoutPendingReview;
}
