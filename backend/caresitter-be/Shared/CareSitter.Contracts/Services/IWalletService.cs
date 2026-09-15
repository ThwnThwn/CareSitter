using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>Payments cung cap thao tac vi/escrow cho cac module khac (dong bo, qua DI).</summary>
public interface IWalletService
{
    Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default);

    Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct = default);

    /// <summary>
    /// Hoàn toàn bộ escrow của booking vào Ví CareSitter của khách.
    /// Idempotent theo bookingId: chạy lại không thể ghi có hai lần.
    /// </summary>
    Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId,
        CancellationToken ct = default);

    Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default);
}
