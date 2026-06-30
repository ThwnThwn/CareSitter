using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

/// <summary>
/// Implement IWalletService (Contracts). Booking goi qua interface, khong cham DbContext Payments.
/// MVP la skeleton: noi ledger that o buoc trien khai Payments.
/// </summary>
internal sealed class WalletService : IWalletService
{
    public Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default)
    {
        // TODO: ghi ledger ESCROW_LOCK (idempotent theo idempotencyKey) trong PaymentsDbContext.
        return Task.FromResult(Result.Success());
    }

    public Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default)
    {
        // TODO: ghi PLATFORM_FEE + CAREGIVER_EARNING (pending 48h) trong PaymentsDbContext.
        return Task.FromResult(Result.Success());
    }
}
