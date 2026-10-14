using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class DisputeLedgerStore(PaymentsDbContext db, WalletLedgerWriter writer)
{
    public async Task<Result> ResolveAsync(Guid bookingId, Guid customerId, Guid caregiverUserId,
        DisputeAllocation allocation, CancellationToken ct)
    {
        var (normalizedDecision, refund, fee, penalty, caregiverAmount) = allocation;
        if (db.Database.IsRelational())
            return await ResolveDisputeRelationalAsync(
                bookingId, customerId, caregiverUserId,
                normalizedDecision, refund, fee, penalty, caregiverAmount, ct);

        var alreadyResolved = await writer.HasDisputeResolutionMarkerAsync(
            bookingId, normalizedDecision, ct);
        if (alreadyResolved) return Result.Success();

        if (refund > 0)
        {
            var customerWallet = await writer.GetOrCreateWalletAsync(customerId, "CUSTOMER", ct);
            var credited = customerWallet.AddAvailable(refund);
            if (credited.IsFailure) return credited.Error;
            var entry = WalletLedgerWriter.CreatePostedEntry("REFUND", "escrow:platform",
                $"wallet:customer:{customerId}", refund, bookingId,
                $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        if (caregiverAmount > 0)
        {
            var caregiverWallet = await writer.GetOrCreateWalletAsync(caregiverUserId, "CAREGIVER", ct);
            var credited = caregiverWallet.AddAvailable(caregiverAmount);
            if (credited.IsFailure) return credited.Error;
            var entry = WalletLedgerWriter.CreatePostedEntry("CAREGIVER_EARNING", "escrow:platform",
                $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId,
                $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        if (fee > 0)
        {
            var entry = WalletLedgerWriter.CreatePostedEntry("PLATFORM_FEE", "escrow:platform",
                "revenue:platform", fee, bookingId,
                $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        if (penalty > 0)
        {
            var entry = WalletLedgerWriter.CreatePostedEntry("PENALTY",
                $"wallet:caregiver:{caregiverUserId}", "revenue:platform",
                penalty, bookingId, $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        await db.SaveChangesAsync(ct);
        return Result.Success();
    }

    private async Task<Result> ResolveDisputeRelationalAsync(
        Guid bookingId,
        Guid customerId,
        Guid caregiverUserId,
        string decision,
        long refund,
        long fee,
        long penalty,
        long caregiverAmount,
        CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            await writer.AcquirePaymentLockAsync(bookingId, ct);
            if (await writer.HasDisputeResolutionMarkerAsync(bookingId, decision, ct))
            {
                await tx.CommitAsync(ct);
                return Result.Success();
            }

            if (refund > 0)
            {
                await writer.EnsureWalletAsync(customerId, "CUSTOMER", ct);
                await db.Database.ExecuteSqlInterpolatedAsync($$"""
                    UPDATE payments.wallet_accounts
                    SET available_balance = available_balance + {{refund}}, updated_at = now()
                    WHERE user_id = {{customerId}} AND account_type = 'CUSTOMER'
                    """, ct);
                var entry = WalletLedgerWriter.CreatePostedEntry("REFUND", "escrow:platform",
                    $"wallet:customer:{customerId}", refund, bookingId,
                    $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            if (caregiverAmount > 0)
            {
                await writer.EnsureWalletAsync(caregiverUserId, "CAREGIVER", ct);
                await db.Database.ExecuteSqlInterpolatedAsync($$"""
                    UPDATE payments.wallet_accounts
                    SET available_balance = available_balance + {{caregiverAmount}}, updated_at = now()
                    WHERE user_id = {{caregiverUserId}} AND account_type = 'CAREGIVER'
                    """, ct);
                var entry = WalletLedgerWriter.CreatePostedEntry("CAREGIVER_EARNING", "escrow:platform",
                    $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId,
                    $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            if (fee > 0)
            {
                var entry = WalletLedgerWriter.CreatePostedEntry("PLATFORM_FEE", "escrow:platform",
                    "revenue:platform", fee, bookingId,
                    $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            if (penalty > 0)
            {
                var entry = WalletLedgerWriter.CreatePostedEntry("PENALTY",
                    $"wallet:caregiver:{caregiverUserId}", "revenue:platform",
                    penalty, bookingId, $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            if (await writer.HasDisputeResolutionMarkerAsync(bookingId, decision, ct))
                return Result.Success();
            throw;
        }
    }
}
