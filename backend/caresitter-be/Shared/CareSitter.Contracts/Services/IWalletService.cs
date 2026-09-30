using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>Payments cung cap thao tac vi/escrow cho cac module khac (dong bo, qua DI).</summary>
public interface IWalletService
{
    Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default);

    Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct = default);

    /// <summary>
    /// Records the platform-funded portion of a promotion in escrow. Idempotent per booking.
    /// </summary>
    Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount,
        CancellationToken ct = default);

    /// <summary>
    /// Hoàn toàn bộ escrow của booking vào Ví CareSitter của khách.
    /// Idempotent theo bookingId: chạy lại không thể ghi có hai lần.
    /// </summary>
    Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId,
        CancellationToken ct = default);

    /// <summary>
    /// Applies the final distribution selected by an admin for a dispute.
    /// The operation is idempotent per booking and writes immutable ledger entries.
    /// </summary>
    Task<Result> ResolveDisputeAsync(
        Guid bookingId,
        Guid customerId,
        Guid caregiverId,
        long escrowAmount,
        long platformFeeAmount,
        string decision,
        long? refundAmount,
        long? caregiverPenaltyAmount,
        CancellationToken ct = default);

    Task<Result> ReleaseMatureSettlementAsync(
        Guid bookingId,
        Guid caregiverId,
        long escrowAmount,
        long platformFeeAmount,
        DateTimeOffset releasedAt,
        CancellationToken ct = default);

    Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default);
}
