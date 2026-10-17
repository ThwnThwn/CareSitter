using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>
/// Booking facts and state changes used by Support without exposing BookingDbContext.
/// </summary>
public sealed record DisputeBookingSnapshot(
    Guid BookingId,
    Guid CustomerId,
    Guid? CaregiverId,
    Guid? CaregiverUserId,
    string Status,
    long EscrowAmount,
    long CustomerPayableAmount,
    long PromotionSubsidyAmount,
    long PlatformFeeAmount,
    int DisputeWindowHours,
    DateTimeOffset ScheduledStart,
    DateTimeOffset? ActualStart,
    DateTimeOffset? ActualEnd,
    DateTimeOffset? SettlementReleasedAt);

public interface IDisputeBookingWorkflow
{
    Task<DisputeBookingSnapshot?> GetAsync(Guid bookingId, CancellationToken ct = default);

    Task<Result> OpenAsync(Guid bookingId, CancellationToken ct = default);

    Task<Result> ResolveAsync(
        Guid bookingId,
        string decision,
        long refundAmount,
        OriginalPaymentRefundState refundState,
        DateTimeOffset resolvedAt,
        CancellationToken ct = default);
}
