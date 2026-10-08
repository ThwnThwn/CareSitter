using System.Text.Json;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PaymentReconciliationProcessor(
    PaymentsDbContext paymentsDb,
    IBookingPaymentGateway bookings,
    IPaymentFinalizationService finalizer,
    IPaymentOutboxDispatcher outbox,
    IAuditLogger auditLogger) : IPaymentReconciliationProcessor
{
    public async Task<IReadOnlyList<PaymentReconciliationItem>> ListAsync(
        CancellationToken ct = default)
    {
        var intents = await paymentsDb.PaymentIntents.AsNoTracking()
            .Where(x => x.ManualReviewReason != null && (x.Status == "PENDING" || x.Provider == "PAYOS"))
            .OrderBy(x => x.ReconciliationStartedAt).Take(100).ToListAsync(ct);
        var bookingIds = intents.Select(x => x.BookingId).Distinct().ToArray();
        var reviewBookings = await bookings.GetManualReviewBookingsAsync(bookingIds, ct);

        return intents.Where(x => reviewBookings.ContainsKey(x.BookingId) || x.Provider == "PAYOS").Select(x =>
            new PaymentReconciliationItem(x.Id, x.BookingId, x.CustomerId, x.Amount,
                x.Currency, x.ProviderOrderRef, x.ProviderTransactionId,
                x.ReconciliationAttempts, x.ReconciliationStartedAt,
                x.LastReconciliationAt, x.LastReconciliationError,
                x.ManualReviewReason, reviewBookings.ContainsKey(x.BookingId) ? "needs_manual_review" : "closed_or_changed",
                reviewBookings.GetValueOrDefault(x.BookingId)?.PaymentDeadline,
                x.Provider, x.Status, x.Status == "PENDING" && reviewBookings.ContainsKey(x.BookingId))).ToArray();
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
        var reviewBookings = await bookings.GetManualReviewBookingsAsync(new[] { intent.BookingId }, ct);
        if (intent.Status != "PENDING" || !reviewBookings.ContainsKey(intent.BookingId))
            return Error.Conflict("payments.review_not_resolvable",
                "Booking đã đóng hoặc chưa ở trạng thái đối soát. Cần xử lý khoản tiền với ngân hàng; không thể xác nhận lại lịch hẹn.");
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
        paymentsDb.ChangeTracker.Clear();
        Guid messageId;
        await using (var tx = await paymentsDb.Database.BeginTransactionAsync(ct))
        {
            var locked = await paymentsDb.PaymentIntents.FromSqlInterpolated(
                    $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (locked is null)
                return Error.NotFound("payments.intent_not_found", "Không tìm thấy payment intent.");
            if (locked.Status != "PENDING")
                return Error.Conflict("payments.intent_changed",
                    "Payment đã được tiến trình khác xử lý.");

            var failed = locked.MarkFailed(payload, PaymentFinalizationSource.AdminManual.ToString());
            if (failed.IsFailure)
                return Error.Conflict("payments.intent_changed", failed.Error.Message);
            locked.SetManualReviewReason(command.Reason);

            var otherPending = await paymentsDb.PaymentIntents.Where(x =>
                x.BookingId == locked.BookingId && x.Id != locked.Id && x.Status == "PENDING")
                .ToListAsync(ct);
            foreach (var other in otherPending) other.MarkSuperseded();

            var message = OutboxMessage.Create(
                new PaymentReviewRejected(locked.BookingId, locked.Id, command.Reason));
            paymentsDb.OutboxMessages.Add(message);
            messageId = message.Id;
            await paymentsDb.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }

        await outbox.DispatchAsync(messageId, ct);
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
        return new PaymentReviewResolution(null, intent.BookingId, "cancelled");
    }
}
