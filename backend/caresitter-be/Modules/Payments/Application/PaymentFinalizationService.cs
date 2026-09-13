using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

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
    IWalletService wallet,
    BookingSyncService bookingSync,
    IMatchingService matching,
    IHubContext<CareTrackingHub> hub,
    IUserNotificationService notifications) : IPaymentFinalizationService
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

        var escrow = await wallet.LockEscrowAsync(booking.Id, intent.Amount,
            $"escrow-lock:{booking.Id}", ct);
        if (escrow.IsFailure) return new(false, "99", escrow.Error.Message);

        var confirm = booking.ConfirmPayment();
        if (confirm.IsFailure) return new(false, "99", confirm.Error.Message);
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.PaymentConfirmed);

        var hold = await bookingDb.CaregiverSlotHolds
            .SingleOrDefaultAsync(x => x.BookingId == booking.Id && x.Status == "HELD", ct);
        hold?.Commit();
        await bookingDb.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var cursor = await bookingSync.GetCurrentCursorAsync(booking.CustomerId, ct);
        await hub.Clients.Group(CareTrackingHub.CustomerGroup(booking.CustomerId))
            .SendAsync("BookingListSync", new { bookingId = booking.Id, booking.SyncVersion, cursor }, ct);
        await notifications.NotifyAsync(new UserNotificationMessage(
            booking.CustomerId, "PAYMENT", "Thanh toán thành công",
            "Booking đã được xác nhận và đang tìm người chăm sóc phù hợp.",
            new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(), ["status"] = "confirmed",
                ["deepLink"] = $"/bookings/{booking.Id}"
            }), ct);
        await matching.OfferTopCandidatesAsync(booking.Id, ct);
        return new(true, "00", "Confirm Success");
    }
}
