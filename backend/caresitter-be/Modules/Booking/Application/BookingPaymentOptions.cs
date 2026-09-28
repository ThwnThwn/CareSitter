namespace CareSitter.Modules.Booking.Application;

public sealed class BookingPaymentOptions
{
    public const string SectionName = "Payments:VNPay";
    public int BookingPaymentDeadlineMinutes { get; init; } = 30;
}
