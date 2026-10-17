using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class RefundStore(PaymentsDbContext db) : IRefundStore
{
    public async Task<Result<OriginalPaymentRefundOutcome>> EnsureRefundAsync(
        Guid bookingId,
        Guid customerId,
        long? amount,
        string reason,
        CancellationToken ct = default)
    {
        var existing = await db.RefundRequests.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (existing is not null)
        {
            if (amount is not null && existing.Amount != amount.Value)
                return Error.Conflict("refund.amount_conflict",
                    "Booking đã có yêu cầu hoàn tiền với số tiền khác; cần đối soát thủ công.");
            return ToOutcome(existing);
        }

        var payment = await db.PaymentIntents.AsNoTracking()
            .Where(x => x.BookingId == bookingId && x.CustomerId == customerId &&
                x.Status == "SUCCEEDED")
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);
        if (payment is null)
            return new OriginalPaymentRefundOutcome(OriginalPaymentRefundState.NotRequired);

        var previousRefund = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
        if (previousRefund)
            return Error.Conflict("refund.existing_ledger",
                "Booking đã có bút toán refund; cần đối soát trước khi hoàn về provider.");

        var canProcessAutomatically = payment.Provider == "VNPAY" &&
            !string.IsNullOrWhiteSpace(payment.ProviderOrderRef) &&
            !string.IsNullOrWhiteSpace(payment.ProviderTransactionId) &&
            !string.IsNullOrWhiteSpace(payment.ProviderCreateDate);
        var requestedAmount = amount ?? payment.Amount;
        var created = RefundRequest.Create(
            payment, requestedAmount, reason, DateTimeOffset.UtcNow,
            canProcessAutomatically);
        if (created.IsFailure) return created.Error;

        db.RefundRequests.Add(created.Value);
        try
        {
            await db.SaveChangesAsync(ct);
            return ToOutcome(created.Value);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            var concurrent = await db.RefundRequests.AsNoTracking()
                .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
            if (concurrent is not null) return ToOutcome(concurrent);
            throw;
        }
    }

    public async Task<RefundWorkItem?> ClaimNextAsync(
        DateTimeOffset now,
        DateTimeOffset leaseUntil,
        DateTimeOffset nextAttemptAt,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var requests = await db.RefundRequests.FromSqlInterpolated($$"""
            SELECT *
            FROM payments.refund_requests
            WHERE provider = 'VNPAY'
              AND status IN ('PENDING', 'PROCESSING', 'UNKNOWN')
              AND (next_attempt_at IS NULL OR next_attempt_at <= {{now}})
              AND (lease_until IS NULL OR lease_until <= {{now}})
            ORDER BY requested_at, id
            LIMIT 1
            FOR UPDATE SKIP LOCKED
            """).ToListAsync(ct);
        var request = requests.SingleOrDefault();
        if (request is null)
        {
            await tx.CommitAsync(ct);
            return null;
        }

        var submit = request.SubmissionStartedAt is null;
        var leaseId = Guid.NewGuid();
        var claimed = request.BeginProviderAttempt(leaseId, now, leaseUntil, nextAttemptAt);
        if (claimed.IsFailure)
        {
            await tx.RollbackAsync(ct);
            return null;
        }

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        db.Entry(request).State = EntityState.Detached;
        return new RefundWorkItem(request, leaseId, submit);
    }

    public async Task<Result> ApplyProviderResultAsync(
        Guid refundRequestId,
        Guid leaseId,
        RefundProviderResult result,
        DateTimeOffset completedAt,
        DateTimeOffset nextAttemptAt,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var request = await LockAsync(refundRequestId, ct);
        if (request is null)
            return Error.NotFound("refund.not_found", "Không tìm thấy yêu cầu hoàn tiền.");
        if (request.Status == "SUCCEEDED")
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }

        var status = result.Outcome switch
        {
            RefundProviderOutcome.Confirmed => "SUCCEEDED",
            RefundProviderOutcome.Rejected => "FAILED",
            RefundProviderOutcome.Processing => "PROCESSING",
            _ => "UNKNOWN"
        };
        var retryAt = status is "PROCESSING" or "UNKNOWN" ? nextAttemptAt : (DateTimeOffset?)null;
        var recorded = request.RecordProviderProgress(
            leaseId,
            status,
            result.ProviderResponseId,
            result.ProviderRefundId,
            result.ProviderTransactionStatus,
            result.ErrorCode,
            retryAt,
            completedAt);
        if (recorded.IsFailure) return recorded.Error;

        if (status == "SUCCEEDED")
        {
            var ledger = await AddConfirmedLedgerAsync(request, ct);
            if (ledger.IsFailure) return ledger;
        }

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Result.Success();
    }

    public async Task<RefundPage> ListForAdminAsync(
        string? status,
        int page,
        int pageSize,
        CancellationToken ct = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var query = db.RefundRequests.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status) &&
            !string.Equals(status, "ALL", StringComparison.OrdinalIgnoreCase))
        {
            var normalized = status.Trim().ToUpperInvariant();
            query = query.Where(x => x.Status == normalized);
        }

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.RequestedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);
        return new RefundPage(items.Select(ToResponse).ToArray(), total, page, pageSize);
    }

    public async Task<CustomerRefundPage> ListForCustomerAsync(
        Guid customerId,
        int page,
        int pageSize,
        CancellationToken ct = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var query = db.RefundRequests.AsNoTracking()
            .Where(x => x.CustomerId == customerId);
        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.RequestedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new CustomerRefundResponse(
                x.Id,
                x.BookingId,
                x.Provider,
                x.Amount,
                x.Currency,
                x.Reason,
                x.Status,
                x.RequestedAt,
                x.CompletedAt))
            .ToListAsync(ct);
        return new CustomerRefundPage(items, total, page, pageSize);
    }

    public async Task<Result<RefundResponse>> ConfirmManualAsync(
        Guid refundRequestId,
        Guid adminId,
        string providerRefundId,
        string confirmationNote,
        DateTimeOffset confirmedAt,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var request = await LockAsync(refundRequestId, ct);
        if (request is null)
            return Error.NotFound("refund.not_found", "Không tìm thấy yêu cầu hoàn tiền.");
        if (request.Status == "SUCCEEDED")
        {
            await tx.CommitAsync(ct);
            return ToResponse(request);
        }

        var confirmed = request.ConfirmManual(
            adminId, providerRefundId, confirmationNote, confirmedAt);
        if (confirmed.IsFailure) return confirmed.Error;
        var ledger = await AddConfirmedLedgerAsync(request, ct);
        if (ledger.IsFailure) return ledger.Error;

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ToResponse(request);
    }

    private Task<RefundRequest?> LockAsync(Guid id, CancellationToken ct) =>
        db.RefundRequests.FromSqlInterpolated(
            $"SELECT * FROM payments.refund_requests WHERE id = {id} FOR UPDATE")
            .SingleOrDefaultAsync(ct);

    private async Task<Result> AddConfirmedLedgerAsync(
        RefundRequest request,
        CancellationToken ct)
    {
        var existing = await db.LedgerEntries.SingleOrDefaultAsync(x =>
            x.BookingId == request.BookingId && x.TransactionType == "REFUND", ct);
        if (existing is not null)
        {
            return existing.PaymentIntentId == request.PaymentIntentId
                ? Result.Success()
                : Error.Conflict("refund.existing_ledger",
                    "Booking đã có bút toán refund khác; không ghi nhận provider lần hai.");
        }

        var metadata = JsonSerializer.Serialize(new
        {
            refund_request_id = request.Id,
            provider = request.Provider,
            provider_refund_id = request.ProviderRefundId,
            provider_response_id = request.ProviderResponseId,
            reason = request.Reason,
            confirmation = request.ConfirmedByAdminId is null ? "provider" : "admin_reconciled"
        });
        var created = LedgerEntry.Create(
            "REFUND",
            "escrow:platform",
            $"provider-refund:{request.Provider.ToLowerInvariant()}",
            request.Amount,
            request.BookingId,
            request.PaymentIntentId,
            request.Currency,
            metadata);
        if (created.IsFailure) return created.Error;
        var posted = created.Value.MarkPosted();
        if (posted.IsFailure) return posted.Error;
        db.LedgerEntries.Add(created.Value);
        return Result.Success();
    }

    private static OriginalPaymentRefundOutcome ToOutcome(RefundRequest request) =>
        new(request.Status switch
        {
            "SUCCEEDED" => OriginalPaymentRefundState.Confirmed,
            "FAILED" => OriginalPaymentRefundState.Failed,
            "MANUAL_REQUIRED" => OriginalPaymentRefundState.ManualActionRequired,
            _ => OriginalPaymentRefundState.Pending
        }, request.Id, request.Provider, request.Amount, request.LastErrorCode);

    internal static RefundResponse ToResponse(RefundRequest request) => new(
        request.Id,
        request.BookingId,
        request.PaymentIntentId,
        request.CustomerId,
        request.Provider,
        request.Amount,
        request.Currency,
        request.Reason,
        request.Status,
        request.RequestId,
        request.OriginalProviderOrderRef,
        request.OriginalProviderTransactionId,
        request.ProviderResponseId,
        request.ProviderRefundId,
        request.ProviderTransactionStatus,
        request.LastErrorCode,
        request.AttemptCount,
        request.RequestedAt,
        request.LastAttemptAt,
        request.NextAttemptAt,
        request.CompletedAt,
        request.ConfirmedByAdminId,
        request.AdminConfirmationNote);
}
