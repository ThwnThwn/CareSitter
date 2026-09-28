using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PaymentFinalizationService(
    PaymentsDbContext paymentsDb,
    IBookingPaymentGateway bookings,
    IMatchingService matching,
    IHubContext<CareTrackingHub> hub,
    IUserNotificationService notifications,
    IAuditLogger auditLogger,
    ILogger<PaymentFinalizationService> logger) : IPaymentFinalizationService
{
    public async Task<PaymentFinalizationResult> FinalizeSuccessfulPaymentAsync(
        Guid intentId, string? transactionId, string? payload,
        PaymentFinalizationSource source, CancellationToken ct = default)
    {
        var intent = await paymentsDb.PaymentIntents.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == intentId, ct);
        if (intent is null) return new(false, "01", "Payment intent not found");

        var ledger = LedgerEntry.Create(
            "ESCROW_LOCK", "customer:escrow", "escrow:platform", intent.Amount,
            intent.BookingId, intent.Id);
        if (ledger.IsFailure) return new(false, "99", ledger.Error.Message);

        var outcome = await bookings.FinalizeAsync(new BookingPaymentFinalization(
            intent.BookingId, intent.Id, intent.Status, intent.Amount, ledger.Value.Id,
            transactionId, payload, source.ToString()), ct);
        if (!outcome.Succeeded || !outcome.NewlyFinalized)
            return new(outcome.Succeeded, outcome.Code, outcome.Message);

        var booking = outcome.Booking!;
        try
        {
            await auditLogger.WriteAsync("PAYMENT_FINALIZED", "PaymentIntent", intent.Id,
                new { paymentStatus = intent.Status, bookingStatus = "pending_payment" },
                new
                {
                    paymentStatus = "SUCCEEDED",
                    bookingStatus = "confirmed",
                    Id = booking.BookingId,
                    intent.Amount,
                    source = source.ToString()
                }, ct);
        }
        catch (Exception ex)
        {
            logger.LogCritical(ex,
                "Payment {PaymentIntentId} finalized but its security audit entry could not be persisted.",
                intent.Id);
        }

        await RunPostCommitActionAsync("booking sync", async () =>
        {
            var cursor = await bookings.GetCurrentSyncCursorAsync(booking.CustomerId, ct);
            await hub.Clients.Group(CareTrackingHub.CustomerGroup(booking.CustomerId))
                .SendAsync("BookingListSync", new
                {
                    bookingId = booking.BookingId,
                    booking.SyncVersion,
                    cursor
                }, ct);
        });
        await RunPostCommitActionAsync("payment notification", () => notifications.NotifyAsync(
            new UserNotificationMessage(
                booking.CustomerId, "PAYMENT", "Thanh toán thành công",
                "Booking đã được xác nhận và đang tìm người chăm sóc phù hợp.",
                new Dictionary<string, string>
                {
                    ["bookingId"] = booking.BookingId.ToString(),
                    ["status"] = "confirmed",
                    ["deepLink"] = $"/bookings/{booking.BookingId}"
                }), ct));
        await RunPostCommitActionAsync("caregiver matching", () =>
            matching.OfferTopCandidatesAsync(booking.BookingId, ct));
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
