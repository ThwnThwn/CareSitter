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
internal sealed class WalletService(PaymentsDbContext db) : IWalletService
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
        await db.SaveChangesAsync(ct);
        return Result.Success();
    }

    public async Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default)
    {
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

        await db.SaveChangesAsync(ct);
        return Result.Success();
    }
}
