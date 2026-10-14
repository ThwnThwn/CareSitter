using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class SettlementLedgerStore(PaymentsDbContext db, WalletLedgerWriter writer)
{
    public async Task<Result> SettleAsync(Guid bookingId, Guid caregiverUserId,
        long caregiverAmount, long platformFeeAmount, CancellationToken ct)
    {
        if (db.Database.IsRelational())
            return await SettleRelationalAsync(
                bookingId, caregiverUserId, caregiverAmount, platformFeeAmount, ct);

        // In-memory path keeps domain unit tests lightweight. PostgreSQL uses the
        // locked/atomic path below and is covered by database race tests.
        bool settled = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
        if (settled) return Result.Success();

        var feeEntry = LedgerEntry.Create("PLATFORM_FEE",
            "escrow:platform", "revenue:platform", platformFeeAmount, bookingId);
        if (feeEntry.IsFailure) return feeEntry.Error;
        feeEntry.Value.MarkPosted();

        var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
            "escrow:platform", $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId);
        if (earningEntry.IsFailure) return earningEntry.Error;
        earningEntry.Value.MarkPosted();

        var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
            x.UserId == caregiverUserId && x.AccountType == "CAREGIVER", ct);
        if (wallet is null)
        {
            var walletResult = WalletAccount.Create(caregiverUserId, "CAREGIVER");
            if (walletResult.IsFailure) return walletResult.Error;
            wallet = walletResult.Value;
            db.WalletAccounts.Add(wallet);
        }

        var creditResult = wallet.AddAvailable(caregiverAmount);
        if (creditResult.IsFailure) return creditResult.Error;

        db.LedgerEntries.Add(feeEntry.Value);
        db.LedgerEntries.Add(earningEntry.Value);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Request complete lặp lại chỉ cần xác nhận settlement đã được ghi bởi request thắng race.
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking()
                .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
            if (!committedByOtherRequest) throw;
        }
        return Result.Success();
    }

    private async Task<Result> SettleRelationalAsync(
        Guid bookingId,
        Guid caregiverUserId,
        long caregiverAmount,
        long platformFeeAmount,
        CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            // Payments owns its concurrency boundary. An advisory transaction lock
            // serializes ledger mutations without locking a Booking-owned row.
            await writer.AcquirePaymentLockAsync(bookingId, ct);

            var settled = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
            if (settled)
            {
                await tx.CommitAsync(ct);
                return Result.Success();
            }

            await db.Database.ExecuteSqlInterpolatedAsync($$"""
                INSERT INTO payments.wallet_accounts (
                    id, user_id, account_type, available_balance, pending_balance,
                    currency, created_at, updated_at)
                VALUES (
                    gen_random_uuid(), {{caregiverUserId}}, 'CAREGIVER', 0, 0,
                    'VND', now(), now())
                ON CONFLICT (user_id) WHERE account_type = 'CAREGIVER' AND user_id IS NOT NULL
                DO NOTHING
                """, ct);

            var feeEntry = LedgerEntry.Create("PLATFORM_FEE",
                "escrow:platform", "revenue:platform", platformFeeAmount, bookingId);
            if (feeEntry.IsFailure) return feeEntry.Error;
            feeEntry.Value.MarkPosted();

            var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
                "escrow:platform", $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId);
            if (earningEntry.IsFailure) return earningEntry.Error;
            earningEntry.Value.MarkPosted();

            db.LedgerEntries.Add(feeEntry.Value);
            db.LedgerEntries.Add(earningEntry.Value);
            await db.SaveChangesAsync(ct);

            var credited = await db.Database.ExecuteSqlInterpolatedAsync($$"""
                UPDATE payments.wallet_accounts
                SET available_balance = available_balance + {{caregiverAmount}}, updated_at = now()
                WHERE user_id = {{caregiverUserId}} AND account_type = 'CAREGIVER'
                """, ct);
            if (credited != 1)
                return Error.Failure("payments.wallet_credit_failed", "Không thể ghi có ví caregiver.");

            await tx.CommitAsync(ct);
            return Result.Success();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
            if (committedByOtherRequest) return Result.Success();
            throw;
        }
    }
}
