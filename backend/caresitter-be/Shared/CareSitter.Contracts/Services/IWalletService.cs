using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>Payments cung cap thao tac vi/escrow cho cac module khac (dong bo, qua DI).</summary>
public interface IWalletService
{
    Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default);

    Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default);
}
