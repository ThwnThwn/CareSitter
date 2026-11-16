using System.Globalization;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSWebhookProcessor(
    PaymentsDbContext db,
    IBookingPaymentGateway bookings,
    IPayOSService service,
    IPaymentFinalizationService finalizer,
    PayOSPaymentReconciliation reconciliation)
{
    public async Task<PayOSWebhookOutcome> ProcessWebhookAsync(JsonElement payload, CancellationToken ct = default)
    {
        if (!service.VerifyWebhook(payload)) return new(400, "Invalid signature.");
        JsonElement data;
        string orderCode, reference, linkId;
        long amount;
        try
        {
            data = payload.GetProperty("data");
            orderCode = data.GetProperty("orderCode").GetInt64().ToString(CultureInfo.InvariantCulture);
            PayOSService.ParseOrderCode(orderCode);
            reference = PayOSService.RequiredString(data, "reference", 200);
            linkId = PayOSService.RequiredString(data, "paymentLinkId", 100);
            amount = data.GetProperty("amount").GetInt64();
            if (amount <= 0 || data.GetProperty("currency").GetString() != "VND" ||
                data.GetProperty("code").GetString() != "00") return new(400, "Invalid payment data.");
        }
        catch (Exception e) when (e is JsonException or FormatException or InvalidDataException or
            InvalidOperationException or KeyNotFoundException) { return new(400, "Invalid payment data."); }
        var intent = await db.PaymentIntents.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Provider == "PAYOS" && x.ProviderOrderRef == orderCode, ct);
        // payOS gửi giao dịch mẫu khi xác thực webhook. Không ghi nhận tiền cho mã không thuộc hệ thống.
        if (intent is null) return new(200, "Accepted.");
        // data.accountNumber identifies the sender account in real payOS transfer
        // callbacks; it is not the merchant receiving account returned when the link
        // was created. Bind the signed callback to our order and paymentLinkId instead.
        if (intent.ProviderLinkId is not null && intent.ProviderLinkId != linkId)
            return new(400, "Payment link mismatch.");

        var eventId = $"{orderCode}:{reference}";
        var webhook = await db.PaymentWebhooks.SingleOrDefaultAsync(x =>
            x.Provider == "PAYOS" && x.ProviderEventId == eventId, ct);
        if (webhook?.Status == "PROCESSED") return new(200, "Accepted.");
        if (webhook is null)
        {
            webhook = PaymentWebhook.Create("PAYOS", eventId, "PAYMENT", payload.GetRawText()).Value;
            db.PaymentWebhooks.Add(webhook);
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: "23505" })
            {
                db.ChangeTracker.Clear();
                webhook = await db.PaymentWebhooks.SingleAsync(x =>
                    x.Provider == "PAYOS" && x.ProviderEventId == eventId, ct);
            }
        }
        PaymentProviderQuery? query = null;
        if (amount != intent.Amount || intent.Status == "SUCCEEDED") query = await service.QueryAsync(intent, ct);
        if (query?.TransactionId is { } queriedId && queriedId != linkId)
            return new(400, "Payment link mismatch.");
        if (intent.Status == "SUCCEEDED" && query!.State != PaymentProviderState.Succeeded)
        {
            if (query.TransactionId is null) return new(503, "Payment requires reconciliation.");
            await reconciliation.RequireManualReviewAsync(intent,
                "PAYOS_ADDITIONAL_PAYMENT: Có khoản tiền bổ sung sau khi đã thanh toán; cần đối chiếu và hoàn tiền thủ công.", ct, allowSucceeded: true);
        }
        else if (amount != intent.Amount && query!.State != PaymentProviderState.Succeeded)
        {
            if (query.TransactionId is null) return new(503, "Payment requires reconciliation.");
            await reconciliation.RequireManualReviewAsync(intent, "PAYOS_AMOUNT_MISMATCH: Khoản tiền nhận được cần đối chiếu với số tiền booking.", ct);
        }
        else if (intent.Status is not ("CREATED" or "PENDING" or "SUCCEEDED"))
        {
            await reconciliation.RequireManualReviewAsync(intent, "PAYOS_LATE_PAYMENT: Nhận tiền sau khi giao dịch đã đóng; cần xử lý thủ công.", ct);
        }
        else
        {
            var booking = await bookings.GetForCustomerAsync(intent.BookingId, intent.CustomerId, ct);
            if (booking is null || booking.State == BookingPaymentState.Other ||
                booking.CustomerPayableAmount != intent.Amount)
            {
                await reconciliation.RequireManualReviewAsync(intent, "PAYOS_BOOKING_CHANGED: Booking đã đóng hoặc thay đổi số tiền; cần đối soát.", ct);
            }
            else
            {
                var result = await finalizer.FinalizeSuccessfulPaymentAsync(intent.Id, linkId,
                    query?.RawPayload ?? payload.GetRawText(), PaymentFinalizationSource.PayOSWebhook, ct);
                if (!result.Succeeded) return new(503, "Payment requires reconciliation.");
            }
        }
        db.ChangeTracker.Clear();
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var locked = await db.PaymentWebhooks.FromSqlInterpolated(
                $"SELECT * FROM payments.payment_webhooks WHERE id = {webhook.Id} FOR UPDATE").SingleAsync(ct);
            if (locked.Status == "RECEIVED") locked.MarkProcessed();
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        return new(200, "Accepted.");
    }
}
