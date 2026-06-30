namespace CareSitter.Modules.Booking.Domain;

/// <summary>12 trang thai don (khop booking_status trong DB).</summary>
public enum BookingStatus
{
    Draft,
    PendingPayment,
    Confirmed,
    CaregiverAccepted,
    CaregiverEnRoute,
    InProgress,
    CheckoutPendingReview,
    Completed,
    Cancelled,
    Crisis,
    Disputed,
    Refunded
}
