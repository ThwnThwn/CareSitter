using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Infrastructure;

// All writers share this scoped DbContext; each operation retains its original transaction boundary.
internal sealed class WalletLedgerStore(PaymentsDbContext db) : IWalletLedgerStore
{
    private readonly EscrowLedgerStore _escrow = new(db);
    private readonly SettlementLedgerStore _settlement = new(db, new WalletLedgerWriter(db));
    private readonly DisputeLedgerStore _dispute = new(db, new WalletLedgerWriter(db));

    public Task<Result> LockEscrowAsync(Guid bookingId, long amount, string key, CancellationToken ct) =>
        _escrow.LockEscrowAsync(bookingId, amount, key, ct);
    public Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount, CancellationToken ct) =>
        _escrow.RecordPromotionSubsidyAsync(bookingId, amount, ct);
    public Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct) =>
        _escrow.ReleaseEscrowAsync(bookingId, amount, ct);
    public Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId, CancellationToken ct) =>
        _escrow.RefundToCustomerWalletAsync(bookingId, customerId, ct);
    public Task<Result> SettleAsync(Guid bookingId, Guid caregiverUserId, long amount, long fee, CancellationToken ct) =>
        _settlement.SettleAsync(bookingId, caregiverUserId, amount, fee, ct);
    public Task<Result> ResolveDisputeAsync(Guid bookingId, Guid customerId, Guid caregiverUserId,
        DisputeAllocation allocation, CancellationToken ct) =>
        _dispute.ResolveAsync(bookingId, customerId, caregiverUserId, allocation, ct);
}
