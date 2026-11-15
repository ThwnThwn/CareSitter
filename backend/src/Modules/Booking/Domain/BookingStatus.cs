namespace CareSitter.Modules.Booking.Domain;

/// <summary>13 trạng thái don (khop booking_status trong DB).</summary>
public enum BookingStatus
{
    Draft,
    PendingPayment,
    PaymentReconciliationPending,
    NeedsManualReview,
    Confirmed,
    MatchingFailed,
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
