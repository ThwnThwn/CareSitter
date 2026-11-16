using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSPaymentReconciliation(
    PaymentsDbContext db,
    IBookingPaymentGateway bookings,
    IPayOSService service,
    IPaymentFinalizationService finalizer,
    IPaymentOutboxDispatcher outbox,
    IOptions<PayOSOptions> options)
{
    public async Task RefreshAsync(Guid intentId, CancellationToken ct = default)
    {
        var intent = await db.PaymentIntents.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == intentId && x.Provider == "PAYOS", ct);
        if (intent is null || intent.Status != "PENDING") return;
        var query = await service.QueryAsync(intent, ct);
        if (query.State == PaymentProviderState.Succeeded)
        {
            var booking = await bookings.GetForCustomerAsync(intent.BookingId, intent.CustomerId, ct);
            if (booking is null || booking.State == BookingPaymentState.Other || booking.CustomerPayableAmount != intent.Amount)
            {
                await RequireManualReviewAsync(intent, "PAYOS_BOOKING_CHANGED: Booking đã đóng hoặc thay đổi số tiền; cần đối soát.", ct);
                return;
            }
            await finalizer.FinalizeSuccessfulPaymentAsync(intent.Id, query.TransactionId, query.RawPayload,
                PaymentFinalizationSource.ReturnFallback, ct);
            return;
        }
        if (query.State is not (PaymentProviderState.Failed or PaymentProviderState.NotFound)) return;
        db.ChangeTracker.Clear();
        Guid messageId;
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var locked = await db.PaymentIntents.FromSqlInterpolated(
                $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE").SingleAsync(ct);
            if (locked.Status != "PENDING") return;
            locked.MarkFailed(query.RawPayload, "PayOSQuery");
            var message = OutboxMessage.Create(new PaymentFailed(locked.BookingId, locked.Id, "PayOSQuery"));
            db.OutboxMessages.Add(message);
            messageId = message.Id;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        await outbox.DispatchAsync(messageId, ct);
    }

    public async Task<string> GetReturnUrlAsync(string? orderCode, CancellationToken ct = default)
    {
        var intent = await db.PaymentIntents.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Provider == "PAYOS" && x.ProviderOrderRef == orderCode, ct);
        if (intent is not null)
        {
            await RefreshAsync(intent.Id, ct);
            intent = await db.PaymentIntents.AsNoTracking().SingleAsync(x => x.Id == intent.Id, ct);
        }
        var query = $"result=pending&provider=PAYOS";
        if (intent is not null) query += $"&bookingId={intent.BookingId}&intentId={intent.Id}";
        var url = options.Value.CustomerWebUrl;
        return !string.IsNullOrWhiteSpace(url)
            ? $"{url.TrimEnd('/')}/#/payment-result?{query}"
            : $"caresitter-customer:/payment-result?{query}";
    }

    public async Task RequireManualReviewAsync(
        PaymentIntent intent, string reason, CancellationToken ct, bool allowSucceeded = false)
    {
        var booking = await bookings.GetForCustomerAsync(intent.BookingId, intent.CustomerId, ct);
        db.ChangeTracker.Clear();
        Guid? messageId = null;
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var locked = await db.PaymentIntents.FromSqlInterpolated(
                $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE").SingleAsync(ct);
            // Không gắn cờ sai cho giao dịch đã hoàn tất trong lúc webhook khác đang xử lý.
            if (locked.Status == "SUCCEEDED" && !allowSucceeded) { await tx.CommitAsync(ct); return; }
            if (locked.ManualReviewReason != reason)
            {
                locked.SetManualReviewReason(reason);
                if (locked.Status == "PENDING" && booking?.State is BookingPaymentState.PendingPayment or BookingPaymentState.PaymentReconciliationPending)
                {
                    var message = OutboxMessage.Create(new PaymentNeedsManualReview(locked.BookingId, locked.Id, reason));
                    db.OutboxMessages.Add(message);
                    messageId = message.Id;
                }
                await db.SaveChangesAsync(ct);
            }
            await tx.CommitAsync(ct);
        }
        if (messageId is { } id) await outbox.DispatchAsync(id, ct);
    }
}
