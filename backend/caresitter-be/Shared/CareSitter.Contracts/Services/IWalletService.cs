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
    /// Bảo đảm có một yêu cầu hoàn toàn bộ số tiền thực thu về phương thức
    /// thanh toán gốc. Lặp lại theo booking không tạo thêm giao dịch refund.
    /// </summary>
    Task<Result<OriginalPaymentRefundOutcome>> RequestOriginalPaymentRefundAsync(
        Guid bookingId,
        Guid customerId,
        string reason,
        CancellationToken ct = default);

    /// <summary>
    /// Bảo đảm hoàn đúng số tiền đã phán quyết về phương thức thanh toán gốc.
    /// Số tiền không được vượt quá payment intent đã thu thành công.
    /// </summary>
    Task<Result<OriginalPaymentRefundOutcome>> RequestOriginalPaymentRefundAsync(
        Guid bookingId,
        Guid customerId,
        long amount,
        string reason,
        CancellationToken ct = default);

    /// <summary>Cho biết settlement đã được ghi bất biến cho booking.</summary>
    Task<bool> HasSettlementAsync(Guid bookingId, CancellationToken ct = default);

    /// <summary>
    /// Applies the final distribution selected by an admin for a dispute.
    /// The operation is idempotent per booking and writes immutable ledger entries.
    /// </summary>
    Task<Result> ResolveDisputeAsync(
        Guid bookingId,
        Guid caregiverId,
        long escrowAmount,
        long customerPayableAmount,
        long promotionSubsidyAmount,
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
