using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Application;

/// <summary>
/// Implement IWalletService (Contracts). Booking goi qua interface, khong cham DbContext Payments.
/// MVP: ghi ledger that vao DB thay vi skeleton.
/// </summary>
internal sealed class WalletService(
    PaymentsDbContext db,
    IDisputeLookupService disputeLookup,
    IPeopleLookupService peopleLookup) : IWalletService
{
    public async Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default)
    {
        // Idempotent: check neu da ghi entry voi cung booking + type
        bool exists = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "ESCROW_LOCK", ct);
        if (exists) return Result.Success(); // da lock roi

        var entry = LedgerEntry.Create("ESCROW_LOCK",
            "customer:escrow", "escrow:platform", amount, bookingId);
        if (entry.IsFailure) return entry.Error;
        db.LedgerEntries.Add(entry.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Hai IPN đồng thời có thể cùng qua bước AnyAsync; unique index là chốt race cuối.
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking()
                .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "ESCROW_LOCK", ct);
            if (!committedByOtherRequest) throw;
        }
        return Result.Success();
    }

    public async Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default)
    {
        if (await disputeLookup.HasOpenDisputeAsync(bookingId, ct))
            return Error.Conflict("payments.dispute_open", "Booking dang co dispute mo, không thể giai ngan escrow.");

        var caregiverUserId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return Error.NotFound("payments.caregiver_not_found", "Không tìm thấy tài khoản của caregiver.");

        var caregiverAmount = escrowAmount - platformFeeAmount;
        if (caregiverAmount <= 0)
            return Error.Validation("payments.invalid_settlement_amount", "Số tiền caregiver nhận phải lớn hơn 0.");

        if (db.Database.IsRelational())
            return await SettleRelationalAsync(
                bookingId, caregiverUserId.Value, caregiverAmount, platformFeeAmount, ct);

        // In-memory path keeps domain unit tests lightweight. PostgreSQL uses the
        // locked/atomic path below and is covered by database race tests.
        bool settled = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
        if (settled) return Result.Success();

        var feeEntry = LedgerEntry.Create("PLATFORM_FEE",
            "escrow:platform", "revenue:platform", platformFeeAmount, bookingId);
        if (feeEntry.IsFailure) return feeEntry.Error;

        var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
            "escrow:platform", $"wallet:caregiver:{caregiverUserId.Value}", caregiverAmount, bookingId);
        if (earningEntry.IsFailure) return earningEntry.Error;

        var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
            x.UserId == caregiverUserId.Value && x.AccountType == "CAREGIVER", ct);
        if (wallet is null)
        {
            var walletResult = WalletAccount.Create(caregiverUserId.Value, "CAREGIVER");
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
            // The booking row is the settlement mutex. All retries for one booking
            // queue here, then re-check the immutable ledger after acquiring it.
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT 1 FROM booking.bookings WHERE id = {bookingId} FOR UPDATE", ct);

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

            var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
                "escrow:platform", $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId);
            if (earningEntry.IsFailure) return earningEntry.Error;

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

    public async Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct = default)
    {
        var lockEntry = await db.LedgerEntries.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId
                && x.TransactionType == "ESCROW_LOCK", ct);
        if (lockEntry is null)
            return Result.Success();

        var alreadyReleased = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
        if (alreadyReleased)
            return Result.Success();

        var refund = LedgerEntry.Create("REFUND",
            "escrow:platform", "customer:escrow", lockEntry.Amount, bookingId,
            metadata: "{\"reason\":\"compensating_release_after_confirm_failure\"}");
        if (refund.IsFailure)
            return refund.Error;

        db.LedgerEntries.Add(refund.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking()
                .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
            if (!committedByOtherRequest) throw;
        }

        return Result.Success();
    }

    public async Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId,
        CancellationToken ct = default)
    {
        // REFUND là chốt idempotency. Không tạo hoặc cộng tiền vào ví lần hai.
        if (await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "REFUND", ct))
            return Result.Success();

        var lockEntry = await db.LedgerEntries.AsNoTracking().SingleOrDefaultAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "ESCROW_LOCK", ct);
        if (lockEntry is null || lockEntry.Amount == 0)
            return Result.Success();

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            // Re-check inside the transaction because Hangfire retries can overlap.
            if (await db.LedgerEntries.AnyAsync(x =>
                    x.BookingId == bookingId && x.TransactionType == "REFUND", ct))
            {
                await tx.CommitAsync(ct);
                return Result.Success();
            }

            var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
                x.UserId == customerId && x.AccountType == "CUSTOMER", ct);
            if (wallet is null)
            {
                var created = WalletAccount.Create(customerId, "CUSTOMER");
                if (created.IsFailure) return created.Error;
                wallet = created.Value;
                db.WalletAccounts.Add(wallet);
            }

            var credit = wallet.AddAvailable(lockEntry.Amount);
            if (credit.IsFailure) return credit.Error;

            var refund = LedgerEntry.Create(
                "REFUND",
                "escrow:platform",
                $"wallet:customer:{customerId}",
                lockEntry.Amount,
                bookingId,
                metadata: "{\"reason\":\"no_caregiver_available_credit_to_customer_wallet\"}");
            if (refund.IsFailure) return refund.Error;

            db.LedgerEntries.Add(refund.Value);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            // Nếu request cạnh tranh đã ghi REFUND thì số dư đã được ghi trong
            // cùng transaction của request đó; coi như thành công.
            var refundedByOtherRequest = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
            if (refundedByOtherRequest) return Result.Success();
            throw;
        }
    }
}
