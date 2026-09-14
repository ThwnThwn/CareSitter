using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Payments.Application;

public enum PaymentFinalizationSource { Ipn, ReturnFallback, RetryPreflight, ReconciliationJob, AdminManual }
public sealed record PaymentFinalizationResult(bool Succeeded, string Code, string Message);

public interface IPaymentFinalizationService
{
    Task<PaymentFinalizationResult> FinalizeSuccessfulPaymentAsync(Guid intentId,
        string? transactionId, string? payload, PaymentFinalizationSource source,
        CancellationToken ct = default);
}

internal sealed class PaymentFinalizationService(
    PaymentsDbContext paymentsDb,
    BookingDbContext bookingDb,
    BookingSyncService bookingSync,
    IMatchingService matching,
    IHubContext<CareTrackingHub> hub,
    IUserNotificationService notifications,
    ILogger<PaymentFinalizationService> logger) : IPaymentFinalizationService
{
    public async Task<PaymentFinalizationResult> FinalizeSuccessfulPaymentAsync(
        Guid intentId, string? transactionId, string? payload,
        PaymentFinalizationSource source, CancellationToken ct = default)
    {
        var bookingId = await paymentsDb.PaymentIntents.AsNoTracking()
            .Where(x => x.Id == intentId)
            .Select(x => (Guid?)x.BookingId)
            .SingleOrDefaultAsync(ct);
        if (bookingId is null) return new(false, "01", "Payment intent not found");

        await using var tx = await bookingDb.Database.BeginTransactionAsync(ct);
        var booking = await bookingDb.Bookings
            .FromSqlInterpolated($"SELECT * FROM booking.bookings WHERE id = {bookingId.Value} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return new(false, "01", "Booking not found");

        // Request co the da cho booking lock; tai lai intent sau khi co lock de
        // khong finalize dua tren status cu ma request khac vua thay doi.
        paymentsDb.ChangeTracker.Clear();
        var intent = await paymentsDb.PaymentIntents.SingleAsync(x => x.Id == intentId, ct);

        // Một request khác đã thắng race. Không ghi đè trạng thái của booking.
        if (booking.Status == BookingStatus.Confirmed)
        {
            await tx.CommitAsync(ct);
            return new(true, "00", "Already finalized");
        }
        if (booking.Status is not (BookingStatus.PendingPayment or BookingStatus.PaymentReconciliationPending
            or BookingStatus.NeedsManualReview))
            return new(false, "99", $"Booking cannot be finalized from {booking.Status}");

        if (intent.Status != "SUCCEEDED")
        {
            var updated = await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
                UPDATE payments.payment_intents
                SET status = 'SUCCEEDED',
                    provider_transaction_id = COALESCE({{transactionId}}, provider_transaction_id),
                    response_payload = CASE WHEN {{payload}} IS NULL
                        THEN response_payload ELSE CAST({{payload}} AS jsonb) END,
                    finalized_source = {{source.ToString()}},
                    next_reconciliation_at = NULL,
                    manual_review_reason = NULL,
                    updated_at = now()
                WHERE id = {{intent.Id}} AND status IN ('CREATED', 'PENDING', 'SUCCEEDED')
                """, ct);
            if (updated == 0)
                return new(false, "99", $"Payment intent cannot be finalized from {intent.Status}");
        }

        await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'SUPERSEDED', next_reconciliation_at = NULL, updated_at = now()
            WHERE booking_id = {{booking.Id}} AND id <> {{intent.Id}} AND status = 'PENDING'
            """, ct);

        // Ghi ledger bang chinh connection dang giu booking FOR UPDATE. Goi
        // IWalletService o day se dung PaymentsDbContext/connection khac va bi
        // FK ledger_entries.booking_id tu cho boi row lock cua transaction nay.
        var escrowEntry = LedgerEntry.Create(
            "ESCROW_LOCK", "customer:escrow", "escrow:platform", intent.Amount,
            booking.Id, intent.Id);
        if (escrowEntry.IsFailure) return new(false, "99", escrowEntry.Error.Message);

        await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
            INSERT INTO payments.ledger_entries (
                id, booking_id, payment_intent_id, transaction_type,
                debit_account, credit_account, amount, currency, status, created_at)
            VALUES (
                {{escrowEntry.Value.Id}}, {{booking.Id}}, {{intent.Id}}, 'ESCROW_LOCK',
                'customer:escrow', 'escrow:platform', {{intent.Amount}}, 'VND', 'PENDING', now())
            ON CONFLICT DO NOTHING
            """, ct);

        var confirm = booking.ConfirmPayment();
        if (confirm.IsFailure) return new(false, "99", confirm.Error.Message);
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.PaymentConfirmed);

        var hold = await bookingDb.CaregiverSlotHolds
            .SingleOrDefaultAsync(x => x.BookingId == booking.Id && x.Status == "HELD", ct);
        hold?.Commit();
        await bookingDb.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        await RunPostCommitActionAsync("booking sync", async () =>
        {
            var cursor = await bookingSync.GetCurrentCursorAsync(booking.CustomerId, ct);
            await hub.Clients.Group(CareTrackingHub.CustomerGroup(booking.CustomerId))
                .SendAsync("BookingListSync", new { bookingId = booking.Id, booking.SyncVersion, cursor }, ct);
        });
        await RunPostCommitActionAsync("payment notification", () => notifications.NotifyAsync(
            new UserNotificationMessage(
                booking.CustomerId, "PAYMENT", "Thanh toán thành công",
                "Booking đã được xác nhận và đang tìm người chăm sóc phù hợp.",
                new Dictionary<string, string>
                {
                    ["bookingId"] = booking.Id.ToString(), ["status"] = "confirmed",
                    ["deepLink"] = $"/bookings/{booking.Id}"
                }), ct));
        await RunPostCommitActionAsync("caregiver matching", () =>
            matching.OfferTopCandidatesAsync(booking.Id, ct));
        return new(true, "00", "Confirm Success");
    }

    private async Task RunPostCommitActionAsync(string action, Func<Task> operation)
    {
        try
        {
            await operation();
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Payment finalization completed, but post-commit {PostCommitAction} failed. The payment will not be rolled back.",
                action);
        }
    }
}
