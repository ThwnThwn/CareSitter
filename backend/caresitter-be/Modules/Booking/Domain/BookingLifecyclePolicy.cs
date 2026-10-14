namespace CareSitter.Modules.Booking.Domain;

internal static class BookingLifecyclePolicy
{
    internal const int LateCheckinGraceMinutes = 10;
    internal const int ShiftEndCheckoutGraceMinutes = 30;
    internal const int AutoConfirmCheckoutHours = 24;

    internal static bool IsSettlementMature(Booking booking, DateTimeOffset now) =>
        booking.Status == BookingStatus.Completed && booking.SettlementReleasedAt is null &&
        booking.ActualEnd is { } ended && booking.CaregiverId is not null &&
        ended.AddHours(booking.DisputeWindowHours) <= now;
}
