namespace CareSitter.Modules.Booking.Application;

public sealed record BookingPaymentSummaryResponse(
    Guid BookingId, string Currency, long AmountDue, long GrossAmount,
    long DiscountAmount, DateTimeOffset PaymentDeadline, bool CanPay,
    int DisputeWindowHours, DateTimeOffset? SettlementEligibleAt,
    bool CanCancel, long? RefundIfCancelledNow, bool RequiresDispute,
    string PaymentExplanation, string SettlementExplanation,
    string MatchingExplanation, string CancellationExplanation,
    DateTimeOffset CalculatedAt,
    long? RefundAfterPaymentIfCancelledNow = null,
    string? AfterPaymentCancellationExplanation = null);
