using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingStatusPresenter
{
    internal static string ToApi(BookingStatus value) => value switch
    {
        BookingStatus.Draft => "draft",
        BookingStatus.PendingPayment => "pending_payment",
        BookingStatus.PaymentReconciliationPending => "payment_reconciliation_pending",
        BookingStatus.NeedsManualReview => "needs_manual_review",
        BookingStatus.Confirmed => "confirmed",
        BookingStatus.MatchingFailed => "matching_failed",
        BookingStatus.CaregiverAccepted => "caregiver_accepted",
        BookingStatus.CaregiverEnRoute => "caregiver_en_route",
        BookingStatus.InProgress => "in_progress",
        BookingStatus.CheckoutPendingReview => "checkout_pending_review",
        BookingStatus.Completed => "completed",
        BookingStatus.Crisis => "crisis",
        BookingStatus.Cancelled => "cancelled",
        BookingStatus.Disputed => "disputed",
        BookingStatus.Refunded => "refunded",
        _ => value.ToString().ToLowerInvariant()
    };
}
