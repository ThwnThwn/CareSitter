using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class AdminPaymentsReader(PaymentsDbContext db) : IAdminPaymentsReader
{
    public async Task<AdminPaymentsSnapshot> GetDashboardSnapshotAsync(CancellationToken ct = default)
    {
        var pendingPayouts = await db.PayoutRequests.AsNoTracking()
            .CountAsync(x => x.Status == "PENDING", ct);
        var manualPayments = await db.PaymentIntents.AsNoTracking()
            .CountAsync(x => x.Status == "PENDING" && x.ManualReviewReason != null, ct);

        var paymentItems = await db.PaymentIntents.AsNoTracking()
            .Where(x => x.Status == "PENDING" && x.ManualReviewReason != null)
            .OrderBy(x => x.ReconciliationStartedAt)
            .Take(5)
            .Select(x => new
            {
                x.Id,
                x.BookingId,
                x.Amount,
                x.ReconciliationStartedAt,
                x.CreatedAt
            })
            .ToListAsync(ct);

        var payoutItems = await db.PayoutRequests.AsNoTracking()
            .Where(x => x.Status == "PENDING")
            .OrderBy(x => x.RequestedAt)
            .Take(5)
            .Select(x => new { x.Id, x.AccountHolderName, x.Amount, x.RequestedAt })
            .ToListAsync(ct);

        var workItems = paymentItems.Select(x => new AdminQueueItem(
                "PAYMENT",
                x.Id,
                "Đối soát thanh toán",
                $"Booking {x.BookingId} · {x.Amount:N0} đ",
                "NEEDS_REVIEW",
                x.ReconciliationStartedAt ?? x.CreatedAt))
            .Concat(payoutItems.Select(x => new AdminQueueItem(
                "PAYOUT",
                x.Id,
                "Yêu cầu rút tiền",
                $"{x.AccountHolderName} · {x.Amount:N0} đ",
                "PENDING",
                x.RequestedAt)))
            .ToArray();

        return new AdminPaymentsSnapshot(pendingPayouts, manualPayments, workItems);
    }
}
