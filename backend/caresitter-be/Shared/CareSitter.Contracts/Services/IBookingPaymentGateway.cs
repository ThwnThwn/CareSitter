namespace CareSitter.Contracts.Services;

/// <summary>
/// Published Booking-module boundary used by Payments. It keeps booking state,
/// slot holds and cross-schema payment transitions behind the owning module.
/// </summary>
public interface IBookingPaymentGateway
{
    Task<BookingPaymentSnapshot?> GetForCustomerAsync(
        Guid bookingId, Guid customerId, CancellationToken ct = default);
    Task<BookingPaymentHoldResult> EnsureSlotHoldAsync(
        Guid bookingId, int reconciliationWindowMinutes, CancellationToken ct = default);
    Task ReleaseSlotHoldAsync(
        Guid bookingId, Guid holdId, CancellationToken ct = default);
    Task<BookingPaymentMutationStatus> ClosePendingIntentAsync(
        Guid bookingId, Guid intentId, string closedStatus, string payload,
        string source, CancellationToken ct = default);
    Task<BookingPaymentFinalizationOutcome> FinalizeAsync(
        BookingPaymentFinalization request, CancellationToken ct = default);
    Task<long> GetCurrentSyncCursorAsync(
        Guid customerId, CancellationToken ct = default);
    Task<BookingPaymentSnapshot?> RecordFailedAttemptAsync(
        Guid bookingId, Guid intentId, string payload, string source,
        CancellationToken ct = default);
    Task<IReadOnlyDictionary<Guid, BookingPaymentSnapshot>> GetManualReviewBookingsAsync(
        IReadOnlyCollection<Guid> bookingIds, CancellationToken ct = default);
    Task<BookingPaymentRejectionOutcome> RejectManualReviewAsync(
        Guid bookingId, Guid intentId, string reason, string payload,
        CancellationToken ct = default);
}

public enum BookingPaymentState
{
    PendingPayment,
    PaymentReconciliationPending,
    NeedsManualReview,
    Confirmed,
    Other
}

public enum BookingPaymentMutationStatus
{
    Succeeded,
    BookingNotFound,
    BookingStateChanged,
    IntentStateChanged,
    CaregiverSlotHeld
}

public sealed record BookingPaymentSnapshot(
    Guid BookingId,
    Guid CustomerId,
    Guid? CaregiverId,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd,
    DateTimeOffset PaymentDeadline,
    long EscrowAmount,
    long SyncVersion,
    BookingPaymentState State);

public sealed record BookingPaymentHoldResult(
    BookingPaymentMutationStatus Status, Guid? CreatedHoldId = null);

public sealed record BookingPaymentFinalization(
    Guid BookingId,
    Guid IntentId,
    string IntentStatus,
    long Amount,
    Guid LedgerEntryId,
    string? ProviderTransactionId,
    string? Payload,
    string Source);

public sealed record BookingPaymentFinalizationOutcome(
    bool Succeeded,
    bool NewlyFinalized,
    string Code,
    string Message,
    BookingPaymentSnapshot? Booking = null);

public sealed record BookingPaymentRejectionOutcome(
    BookingPaymentMutationStatus Status,
    BookingPaymentSnapshot? Booking = null);
