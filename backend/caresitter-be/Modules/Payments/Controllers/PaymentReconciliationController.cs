using System.Text.Json;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/payment-reconciliation")]
public sealed class PaymentReconciliationController(
    PaymentsDbContext paymentsDb,
    BookingDbContext bookingDb,
    BookingSyncService bookingSync,
    IPaymentFinalizationService finalizer) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var intents = await paymentsDb.PaymentIntents.AsNoTracking()
            .Where(x => x.Status == "PENDING" && x.ManualReviewReason != null)
            .OrderBy(x => x.ReconciliationStartedAt)
            .Take(100)
            .ToListAsync(ct);
        var bookingIds = intents.Select(x => x.BookingId).Distinct().ToArray();
        var bookings = await bookingDb.Bookings.AsNoTracking()
            .Where(x => bookingIds.Contains(x.Id) && x.Status == BookingStatus.NeedsManualReview)
            .ToDictionaryAsync(x => x.Id, ct);

        return Ok(intents.Where(x => bookings.ContainsKey(x.BookingId)).Select(x => new
        {
            intentId = x.Id,
            x.BookingId,
            x.CustomerId,
            x.Amount,
            x.Currency,
            x.ProviderOrderRef,
            x.ProviderTransactionId,
            x.ReconciliationAttempts,
            x.ReconciliationStartedAt,
            x.LastReconciliationAt,
            x.LastReconciliationError,
            x.ManualReviewReason,
            bookingStatus = "needs_manual_review",
            paymentDeadline = bookings[x.BookingId].PaymentDeadline
        }));
    }

    [HttpPost("{intentId:guid}/resolve")]
    public async Task<IActionResult> Resolve(Guid intentId,
        [FromBody] ResolvePaymentReviewRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            return BadRequest(new { error = "Ly do xu ly thu cong la bat buoc." });
        var intent = await paymentsDb.PaymentIntents.SingleOrDefaultAsync(x => x.Id == intentId, ct);
        if (intent is null) return NotFound();

        if (request.Succeeded)
        {
            var result = await finalizer.FinalizeSuccessfulPaymentAsync(intentId,
                request.ProviderTransactionId, JsonSerializer.Serialize(new { request.Reason }),
                PaymentFinalizationSource.AdminManual, ct);
            return result.Succeeded ? Ok(result) : Conflict(result);
        }

        await using var tx = await bookingDb.Database.BeginTransactionAsync(ct);
        var booking = await bookingDb.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {intent.BookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return NotFound();
        if (booking.Status != BookingStatus.NeedsManualReview)
            return Conflict(new { error = "Booking da duoc tien trinh khac xu ly." });

        var payload = JsonSerializer.Serialize(new { request.Reason, source = "AdminManual" });
        var updated = await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'FAILED', response_payload = CAST({{payload}} AS jsonb),
                manual_review_reason = {{request.Reason.Trim()}}, finalized_source = 'AdminManual',
                next_reconciliation_at = NULL, updated_at = now()
            WHERE id = {{intent.Id}} AND status = 'PENDING'
            """, ct);
        if (updated == 0)
            return Conflict(new { error = "Payment da duoc tien trinh khac xu ly." });
        await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'SUPERSEDED', next_reconciliation_at = NULL, updated_at = now()
            WHERE booking_id = {{booking.Id}} AND id <> {{intent.Id}} AND status = 'PENDING'
            """, ct);

        var cancelled = booking.Cancel(booking.CustomerId, "ADMIN",
            $"PAYMENT_MANUAL_REJECTED: {request.Reason}", DateTimeOffset.UtcNow);
        if (cancelled.IsFailure) return Conflict(new { error = cancelled.Error.Message });
        var holds = await bookingDb.CaregiverSlotHolds
            .Where(x => x.BookingId == booking.Id && x.Status == "HELD").ToListAsync(ct);
        foreach (var hold in holds) hold.Release();
        bookingSync.WriteSyncEvent(booking, "PAYMENT_MANUAL_REJECTED");
        await bookingDb.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Ok(new { bookingId = booking.Id, status = "cancelled" });
    }
}

public sealed record ResolvePaymentReviewRequest(
    bool Succeeded, string Reason, string? ProviderTransactionId = null);
