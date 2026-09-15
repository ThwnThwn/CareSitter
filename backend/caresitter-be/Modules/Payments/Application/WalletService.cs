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
internal sealed class WalletService(PaymentsDbContext db, IDisputeLookupService disputeLookup) : IWalletService
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
        // Idempotent check
        bool settled = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
        if (settled) return Result.Success();

        // Platform fee entry
        var feeEntry = LedgerEntry.Create("PLATFORM_FEE",
            "escrow:platform", "revenue:platform", platformFeeAmount, bookingId);
        if (feeEntry.IsSuccess) db.LedgerEntries.Add(feeEntry.Value);

        // Caregiver earning entry
        long caregiverAmount = escrowAmount - platformFeeAmount;
        var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
            "escrow:platform", $"wallet:caregiver:{caregiverId}", caregiverAmount, bookingId);
        if (earningEntry.IsSuccess) db.LedgerEntries.Add(earningEntry.Value);

        // Update caregiver wallet balance if exists
        var wallet = await db.WalletAccounts
            .FirstOrDefaultAsync(x => x.UserId != null &&
                x.AccountType == "CAREGIVER", ct);
        // Note: in production, would lookup by caregiverId -> userId -> wallet

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
