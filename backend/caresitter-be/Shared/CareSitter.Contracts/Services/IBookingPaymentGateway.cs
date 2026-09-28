namespace CareSitter.Contracts.Services;

/// <summary>
/// Published Booking-module boundary used by Payments. Every operation in this
/// contract is owned and persisted by Booking; Payments never receives a Booking DbContext.
/// </summary>
public interface IBookingPaymentGateway
{
    Task<BookingPaymentSnapshot?> GetForCustomerAsync(
        Guid bookingId, Guid customerId, CancellationToken ct = default);
    Task<BookingPaymentHoldResult> EnsureSlotHoldAsync(
        Guid bookingId, int reconciliationWindowMinutes, CancellationToken ct = default);
    Task ReleaseSlotHoldAsync(
        Guid bookingId, Guid holdId, CancellationToken ct = default);
    Task<IReadOnlyDictionary<Guid, BookingPaymentSnapshot>> GetManualReviewBookingsAsync(
        IReadOnlyCollection<Guid> bookingIds, CancellationToken ct = default);
    Task<IReadOnlyList<Guid>> ListDuePaymentBookingIdsAsync(
        DateTimeOffset now, int batchSize, CancellationToken ct = default);
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
