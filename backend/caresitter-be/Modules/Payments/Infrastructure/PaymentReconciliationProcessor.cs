using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PaymentReconciliationProcessor(
    PaymentsDbContext paymentsDb,
    IBookingPaymentGateway bookings,
    IPaymentFinalizationService finalizer,
    IAuditLogger auditLogger) : IPaymentReconciliationProcessor
{
    public async Task<IReadOnlyList<PaymentReconciliationItem>> ListAsync(
        CancellationToken ct = default)
    {
        var intents = await paymentsDb.PaymentIntents.AsNoTracking()
            .Where(x => x.Status == "PENDING" && x.ManualReviewReason != null)
            .OrderBy(x => x.ReconciliationStartedAt).Take(100).ToListAsync(ct);
        var bookingIds = intents.Select(x => x.BookingId).Distinct().ToArray();
        var reviewBookings = await bookings.GetManualReviewBookingsAsync(bookingIds, ct);

        return intents.Where(x => reviewBookings.ContainsKey(x.BookingId)).Select(x =>
            new PaymentReconciliationItem(x.Id, x.BookingId, x.CustomerId, x.Amount,
                x.Currency, x.ProviderOrderRef, x.ProviderTransactionId,
                x.ReconciliationAttempts, x.ReconciliationStartedAt,
                x.LastReconciliationAt, x.LastReconciliationError,
                x.ManualReviewReason, "needs_manual_review",
                reviewBookings[x.BookingId].PaymentDeadline)).ToArray();
    }

    public async Task<Result<PaymentReviewResolution>> ResolveAsync(
        ResolvePaymentReviewCommand command, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(command.Reason))
            return Error.Validation("payments.review_reason_required",
                "Ly do xu ly thủ công la bat buoc.");
        var intent = await paymentsDb.PaymentIntents.SingleOrDefaultAsync(
            x => x.Id == command.IntentId, ct);
        if (intent is null)
            return Error.NotFound("payments.intent_not_found", "Không tìm thấy payment intent.");
        var before = new { intent.Status, intent.BookingId, intent.Amount, intent.ManualReviewReason };

        if (command.Succeeded)
        {
            var finalization = await finalizer.FinalizeSuccessfulPaymentAsync(intent.Id,
                command.ProviderTransactionId, JsonSerializer.Serialize(new { command.Reason }),
                PaymentFinalizationSource.AdminManual, ct);
            await auditLogger.WriteAsync(
                finalization.Succeeded
                    ? "ADMIN_PAYMENT_RECONCILIATION_APPROVED"
                    : "ADMIN_PAYMENT_RECONCILIATION_FAILED",
                "PaymentIntent", intent.Id, before,
                new
                {
                    finalization.Succeeded,
                    intent.BookingId,
                    intent.Amount,
                    command.Reason,
                    command.ProviderTransactionId
                }, ct);
            return new PaymentReviewResolution(finalization, null, null);
        }

        var payload = JsonSerializer.Serialize(new { command.Reason, source = "AdminManual" });
        var rejection = await bookings.RejectManualReviewAsync(
            intent.BookingId, intent.Id, command.Reason, payload, ct);
        if (rejection.Status == BookingPaymentMutationStatus.BookingNotFound)
            return Error.NotFound("payments.booking_not_found", "Không tìm thấy booking.");
        if (rejection.Status == BookingPaymentMutationStatus.BookingStateChanged)
            return Error.Conflict("payments.booking_changed",
                "Booking đã được tiến trình khác xử lý.");
        if (rejection.Status == BookingPaymentMutationStatus.IntentStateChanged)
            return Error.Conflict("payments.intent_changed",
                "Payment đã được tiến trình khác xử lý.");
        if (rejection.Status != BookingPaymentMutationStatus.Succeeded)
            return Error.Conflict("payments.booking_changed",
                "Booking đã được tiến trình khác xử lý.");
        var booking = rejection.Booking!;
        await auditLogger.WriteAsync(
            "ADMIN_PAYMENT_RECONCILIATION_REJECTED", "PaymentIntent", intent.Id,
            before, new
            {
                status = "FAILED",
                intent.BookingId,
                intent.Amount,
                command.Reason,
                bookingStatus = "CANCELLED"
            }, ct);
        return new PaymentReviewResolution(null, booking.BookingId, "cancelled");
    }
}
