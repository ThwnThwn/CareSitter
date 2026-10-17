using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class WalletLedgerWriter(PaymentsDbContext db)
{
    internal Task AcquirePaymentLockAsync(Guid bookingId, CancellationToken ct) =>
        db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({bookingId.ToString()}, 0))", ct);

    internal Task<bool> HasDisputeResolutionMarkerAsync(
        Guid bookingId, string decision, CancellationToken ct) =>
        db.LedgerEntries.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId &&
            x.TransactionType == "DISPUTE_RESOLUTION", ct);

    internal Task<bool> HasSettlementAsync(Guid bookingId, CancellationToken ct) =>
        db.LedgerEntries.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId &&
            (x.TransactionType == "CAREGIVER_EARNING" ||
             x.TransactionType == "DISPUTE_RESOLUTION"), ct);

    internal async Task<WalletAccount> GetOrCreateWalletAsync(
        Guid userId, string accountType, CancellationToken ct)
    {
        var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
            x.UserId == userId && x.AccountType == accountType, ct);
        if (wallet is not null) return wallet;
        wallet = WalletAccount.Create(userId, accountType).Value;
        db.WalletAccounts.Add(wallet);
        return wallet;
    }

    internal Task<int> EnsureWalletAsync(Guid userId, string accountType, CancellationToken ct) =>
        db.Database.ExecuteSqlInterpolatedAsync($$"""
            INSERT INTO payments.wallet_accounts (
                id, user_id, account_type, available_balance, pending_balance,
                currency, created_at, updated_at)
            VALUES (gen_random_uuid(), {{userId}}, {{accountType}}, 0, 0, 'VND', now(), now())
            ON CONFLICT DO NOTHING
            """, ct);

    internal static Result<LedgerEntry> CreatePostedEntry(
        string type, string debit, string credit, long amount,
        Guid bookingId, string metadata)
    {
        var entry = LedgerEntry.Create(type, debit, credit, amount, bookingId, metadata: metadata);
        if (entry.IsFailure) return entry.Error;
        var posted = entry.Value.MarkPosted();
        return posted.IsFailure ? posted.Error : entry.Value;
    }
}
