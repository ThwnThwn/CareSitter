using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class EscrowLedgerStore(PaymentsDbContext db)
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

    public async Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount,
        CancellationToken ct = default)
    {
        var exists = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "PROMOTION_SUBSIDY", ct);
        if (exists) return Result.Success();

        var entry = LedgerEntry.Create("PROMOTION_SUBSIDY",
            "revenue:platform", "escrow:platform", amount, bookingId,
            metadata: "{\"funding\":\"platform\"}");
        if (entry.IsFailure) return entry.Error;
        entry.Value.MarkPosted();
        db.LedgerEntries.Add(entry.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            if (!await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                    x.BookingId == bookingId &&
                    x.TransactionType == "PROMOTION_SUBSIDY", ct))
                throw;
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
        refund.Value.MarkPosted();

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

}
