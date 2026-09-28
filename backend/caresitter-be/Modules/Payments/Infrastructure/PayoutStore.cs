using CareSitter.Modules.Payments.Application.Payouts;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayoutStore(PaymentsDbContext db) : IPayoutStore
{
    public Task<PayoutRequest?> FindExistingAsync(
        Guid caregiverId, string idempotencyKey, CancellationToken ct = default) =>
        db.PayoutRequests.AsNoTracking().SingleOrDefaultAsync(x =>
            x.CaregiverId == caregiverId && x.IdempotencyKey == idempotencyKey, ct);

    public Task<WalletAccount?> FindCaregiverWalletAsync(
        Guid userId, CancellationToken ct = default) =>
        db.WalletAccounts.AsNoTracking().FirstOrDefaultAsync(
            x => x.UserId == userId && x.AccountType == "CAREGIVER", ct);

    public async Task<PayoutCreateStatus> CreateAsync(
        PayoutRequest payout, long amount, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            var reserved = await db.Database.ExecuteSqlInterpolatedAsync($$"""
                UPDATE payments.wallet_accounts
                SET available_balance = available_balance - {{amount}},
                    pending_balance = pending_balance + {{amount}},
                    updated_at = now()
                WHERE id = {{payout.WalletAccountId}} AND available_balance >= {{amount}}
                """, ct);
            if (reserved == 0)
            {
                await tx.RollbackAsync(ct);
                db.ChangeTracker.Clear();
                return PayoutCreateStatus.InsufficientBalance;
            }

            db.PayoutRequests.Add(payout);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return PayoutCreateStatus.Created;
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            if (await FindExistingAsync(payout.CaregiverId, payout.IdempotencyKey, ct) is not null)
                return PayoutCreateStatus.ConcurrentDuplicate;
            throw;
        }
    }

    public async Task<Result<PayoutRequest>> ApproveAsync(
        Guid payoutId, Guid adminId, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var payout = await db.PayoutRequests.FromSqlInterpolated(
            $"SELECT * FROM payments.payout_requests WHERE id = {payoutId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (payout is null) return PayoutErrors.NotFound();

        var approved = payout.Approve(adminId);
        if (approved.IsFailure) return approved.Error;
        var ledger = LedgerEntry.Create("PAYOUT", $"wallet:caregiver:{payout.CaregiverId}",
            "bank:external", payout.Amount,
            metadata: $"{{\"payout_request_id\":\"{payout.Id}\"}}",
            payoutRequestId: payout.Id);
        if (ledger.IsFailure) return ledger.Error;
        var posted = ledger.Value.MarkPosted();
        if (posted.IsFailure) return posted.Error;
        db.LedgerEntries.Add(ledger.Value);

        var released = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.wallet_accounts
            SET pending_balance = pending_balance - {{payout.Amount}}, updated_at = now()
            WHERE id = {{payout.WalletAccountId}} AND pending_balance >= {{payout.Amount}}
            """, ct);
        if (released == 0) return PayoutErrors.InvalidBalance();
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return payout;
    }

    public async Task<Result<PayoutRequest>> RejectAsync(
        Guid payoutId, Guid adminId, string? reason, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var payout = await db.PayoutRequests.FromSqlInterpolated(
            $"SELECT * FROM payments.payout_requests WHERE id = {payoutId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (payout is null) return PayoutErrors.NotFound();

        var rejected = payout.Reject(adminId, reason);
        if (rejected.IsFailure) return rejected.Error;
        var restored = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.wallet_accounts
            SET available_balance = available_balance + {{payout.Amount}},
                pending_balance = pending_balance - {{payout.Amount}},
                updated_at = now()
            WHERE id = {{payout.WalletAccountId}} AND pending_balance >= {{payout.Amount}}
            """, ct);
        if (restored == 0) return PayoutErrors.InvalidBalance();
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return payout;
    }

    public async Task<PayoutPage> ListForCaregiverAsync(
        Guid caregiverId, int page, int pageSize, PayoutMapper mapper,
        CancellationToken ct = default)
    {
        var query = db.PayoutRequests.AsNoTracking().Where(x => x.CaregiverId == caregiverId);
        var total = await query.CountAsync(ct);
        var payouts = await query.OrderByDescending(x => x.RequestedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PayoutPage(payouts.Select(x => mapper.ToResponse(x)).ToList(),
            total, page, pageSize);
    }

    public async Task<PayoutPage> ListForAdminAsync(
        string? status, int page, int pageSize, PayoutMapper mapper,
        CancellationToken ct = default)
    {
        var query = db.PayoutRequests.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status) &&
            !string.Equals(status, "ALL", StringComparison.OrdinalIgnoreCase))
        {
            var normalized = status.Trim().ToUpperInvariant();
            query = query.Where(x => x.Status == normalized);
        }

        var total = await query.CountAsync(ct);
        var payouts = await query.OrderBy(x => x.RequestedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PayoutPage(
            payouts.Select(x => mapper.ToResponse(x, revealAccountNumber: true)).ToList(),
            total, page, pageSize);
    }
}
