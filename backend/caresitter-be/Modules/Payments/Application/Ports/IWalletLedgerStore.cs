using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

internal interface IWalletLedgerStore
{
    Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct);
    Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount, CancellationToken ct);
    Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct);
    Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId, CancellationToken ct);
    Task<Result> SettleAsync(Guid bookingId, Guid caregiverUserId, long caregiverAmount, long platformFeeAmount, CancellationToken ct);
    Task<Result> ResolveDisputeAsync(Guid bookingId, Guid customerId, Guid caregiverUserId, DisputeAllocation allocation, CancellationToken ct);
}
