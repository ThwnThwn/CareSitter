using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Infrastructure;

// All writers share this scoped DbContext; each operation retains its original transaction boundary.
internal sealed class WalletLedgerStore(
    PaymentsDbContext db,
    IDisputeLookupService disputes) : IWalletLedgerStore
{
    private readonly WalletLedgerWriter _writer = new(db);
    private readonly EscrowLedgerStore _escrow = new(db);
    private readonly SettlementLedgerStore _settlement = new(
        db, new WalletLedgerWriter(db), disputes);
    private readonly DisputeLedgerStore _dispute = new(db, new WalletLedgerWriter(db));

    public Task<Result> LockEscrowAsync(Guid bookingId, long amount, string key, CancellationToken ct) =>
        _escrow.LockEscrowAsync(bookingId, amount, key, ct);
    public Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount, CancellationToken ct) =>
        _escrow.RecordPromotionSubsidyAsync(bookingId, amount, ct);
    public Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct) =>
        _escrow.ReleaseEscrowAsync(bookingId, amount, ct);
    public Task<bool> HasSettlementAsync(Guid bookingId, CancellationToken ct) =>
        _writer.HasSettlementAsync(bookingId, ct);
    public Task<Result> SettleAsync(Guid bookingId, Guid caregiverUserId, long amount, long fee, CancellationToken ct) =>
        _settlement.SettleAsync(bookingId, caregiverUserId, amount, fee, ct);
    public Task<Result> ResolveDisputeAsync(Guid bookingId, Guid caregiverUserId,
        DisputeAllocation allocation, CancellationToken ct) =>
        _dispute.ResolveAsync(bookingId, caregiverUserId, allocation, ct);
}
