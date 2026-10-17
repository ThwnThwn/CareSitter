using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.PaymentIntents;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSPaymentPortal(PaymentsDbContext db, IBookingPaymentGateway bookings,
    IPayOSService service, IPaymentFinalizationService finalizer, IPaymentOutboxDispatcher outbox,
    IOptions<PayOSOptions> options, IOptions<VNPayOptions> timing, IClock clock) : IPayOSPaymentPortal
{
    public async Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(Guid bookingId,
        Guid userId, CancellationToken ct = default)
    {
        if (!options.Value.Enabled)
            return Error.Validation("PAYMENT_PROVIDER_UNAVAILABLE", "Phương thức thanh toán này hiện chưa khả dụng.");
        var booking = await bookings.GetForCustomerAsync(bookingId, userId, ct);
        if (booking is null) return Error.NotFound("payments.booking_not_found", "Không tìm thấy booking.");
        var admission = PaymentIntentCreationPolicy.CheckBooking(booking, clock.UtcNow);
        if (admission is not null) return Conflict(admission.Error, admission.Code);
        if (booking.CustomerPayableAmount <= 0)
            return Error.Validation("payments.amount", "Booking này không có số tiền cần thu qua cổng thanh toán.");
        if (await db.PaymentIntents.AnyAsync(x => x.BookingId == bookingId && x.Status == "SUCCEEDED", ct))
            return Conflict("Booking đã thanh toán thành công.", "PAYMENT_ALREADY_SUCCEEDED");

        var intent = await ActiveIntentAsync(bookingId, ct);
        if (intent is not null && intent.Provider != "PAYOS") return ProviderInProgress();
        var created = intent is null;
        if (intent is null)
        {
            var hold = await bookings.EnsureSlotHoldAsync(bookingId, timing.Value.ReconciliationWindowMinutes, ct);
            if (hold.Status != BookingPaymentMutationStatus.Succeeded)
                return Conflict("Chưa thể giữ chỗ cho booking. Vui lòng tải lại.", "PAYMENT_STATE_CHANGED");
            intent = PaymentIntent.Create(bookingId, userId, "PAYOS", booking.CustomerPayableAmount,
                $"payos-{Guid.NewGuid():N}", createdAt: clock.UtcNow).Value;
            var orderCode = (BitConverter.ToUInt64(RandomNumberGenerator.GetBytes(8)) & 0x1fffffffffffffUL) + 1;
            if (orderCode > 9_007_199_254_740_991UL) orderCode = 1;
            intent.SetProviderOrderRef(orderCode.ToString(CultureInfo.InvariantCulture));
            intent.ConfigurePayOS(booking.PaymentDeadline);
            intent.MarkPending();
            db.PaymentIntents.Add(intent);
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateException exception) when (exception.InnerException is PostgresException { SqlState: "23505" })
            {
                db.ChangeTracker.Clear();
                intent = await ActiveIntentAsync(bookingId, ct);
                if (intent is null) throw;
                if (intent.Provider != "PAYOS") return ProviderInProgress();
                created = false;
            }
        }

        // Lưu mã đơn trước POST. Khi mất response, retry dùng đúng mã đã lưu.
        if (!created)
        {
            await RefreshAsync(intent.Id, ct);
            db.ChangeTracker.Clear();
            intent = await db.PaymentIntents.SingleAsync(x => x.Id == intent.Id, ct);
            if (intent.Status == "SUCCEEDED")
                return Conflict("Giao dịch đã thanh toán thành công.", "PAYMENT_ALREADY_SUCCEEDED");
            if (intent.Status != "PENDING")
                return Conflict("Giao dịch đã đóng. Vui lòng tải lại booking.", "PAYMENT_STATE_CHANGED");
            if (intent.CheckoutUrl is not null)
                return new PaymentIntentCreationOutcome(ToResponse(intent), false);
        }

        PayOSPaymentLink? link = null;
        try { link = await service.CreateLinkAsync(intent, ct); }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or InvalidDataException or
            JsonException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            if (ct.IsCancellationRequested) throw;
            var query = await service.QueryAsync(intent, ct);
            if (query.State == PaymentProviderState.Succeeded)
            {
                await finalizer.FinalizeSuccessfulPaymentAsync(intent.Id, query.TransactionId,
                    query.RawPayload, PaymentFinalizationSource.RetryPreflight, ct);
                return Conflict("Giao dịch đã được ghi nhận. Vui lòng tải lại booking.", "PAYMENT_ALREADY_SUCCEEDED");
            }
            if (query.State == PaymentProviderState.Processing && query.TransactionId is { } id)
                link = new(PayOSService.ParseOrderCode(intent.ProviderOrderRef), intent.Amount, id,
                    $"https://pay.payos.vn/web/{Uri.EscapeDataString(id)}", "", query.RawPayload);
            else
                return Conflict("Chưa xác minh được giao dịch. Hệ thống giữ nguyên mã thanh toán để tránh thu tiền hai lần.",
                    "PAYMENT_STATUS_UNKNOWN");
        }

        // Không ghi đè SUCCEEDED nếu webhook đến trong lúc POST đang trả response.
        db.ChangeTracker.Clear();
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var locked = await db.PaymentIntents.FromSqlInterpolated(
                $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE").SingleAsync(ct);
            var attached = locked.AttachPayOSLink(link.PaymentLinkId, link.CheckoutUrl,
                string.IsNullOrEmpty(link.AccountNumber) ? null : link.AccountNumber);
            if (attached.IsFailure) return attached.Error;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            intent = locked;
        }
        return new PaymentIntentCreationOutcome(ToResponse(intent), created);
    }

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
            await RequireManualReviewAsync(intent,
                "PAYOS_ADDITIONAL_PAYMENT: Có khoản tiền bổ sung sau khi đã thanh toán; cần đối chiếu và hoàn tiền thủ công.", ct, allowSucceeded: true);
        }
        else if (amount != intent.Amount && query!.State != PaymentProviderState.Succeeded)
        {
            if (query.TransactionId is null) return new(503, "Payment requires reconciliation.");
            await RequireManualReviewAsync(intent, "PAYOS_AMOUNT_MISMATCH: Khoản tiền nhận được cần đối chiếu với số tiền booking.", ct);
        }
        else if (intent.Status is not ("CREATED" or "PENDING" or "SUCCEEDED"))
        {
            await RequireManualReviewAsync(intent, "PAYOS_LATE_PAYMENT: Nhận tiền sau khi giao dịch đã đóng; cần xử lý thủ công.", ct);
        }
        else
        {
            var booking = await bookings.GetForCustomerAsync(intent.BookingId, intent.CustomerId, ct);
            if (booking is null || booking.State == BookingPaymentState.Other ||
                booking.CustomerPayableAmount != intent.Amount)
            {
                await RequireManualReviewAsync(intent, "PAYOS_BOOKING_CHANGED: Booking đã đóng hoặc thay đổi số tiền; cần đối soát.", ct);
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

    private async Task RequireManualReviewAsync(PaymentIntent intent, string reason, CancellationToken ct, bool allowSucceeded = false)
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

    private Task<PaymentIntent?> ActiveIntentAsync(Guid bookingId, CancellationToken ct) =>
        db.PaymentIntents.AsNoTracking().SingleOrDefaultAsync(x => x.BookingId == bookingId &&
            (x.Status == "CREATED" || x.Status == "PENDING"), ct);
    private static Result<PaymentIntentCreationOutcome> ProviderInProgress() =>
        Conflict("Booking đang có giao dịch tại cổng khác. Hãy hoàn tất hoặc hủy giao dịch đó trước.", "PAYMENT_PROVIDER_IN_PROGRESS");
    private static Result<PaymentIntentCreationOutcome> Conflict(string message, string? code) =>
        new PaymentIntentCreationOutcome(null, false, new PaymentIntentConflict(message, code));
    internal static PaymentIntentResponse ToResponse(PaymentIntent intent) => new(intent.Id,
        intent.BookingId, intent.CustomerId, intent.Provider, intent.Amount, intent.Currency, intent.Status,
        intent.ProviderTransactionId, intent.IdempotencyKey, intent.CreatedAt,
        intent.Status == "PENDING" ? intent.CheckoutUrl : null, intent.ProviderOrderRef);
}
