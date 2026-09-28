using System.Globalization;
using System.Text.Json;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class VNPayCallbackProcessor(
    PaymentsDbContext paymentsDb,
    IVNPayService vnPay,
    IPaymentFinalizationService finalizer,
    IPaymentOutboxDispatcher outbox,
    IOptions<VNPayOptions> options,
    IUserNotificationService notifications) : IVnPayCallbackProcessor
{
    public async Task<VnPayIpnResult> ProcessIpnAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct = default)
    {
        if (!vnPay.VerifyCallback(values, options.Value))
            return new VnPayIpnResult("97", "Invalid signature");

        var validation = await FindAndValidateIntentAsync(values, ct);
        if (validation.ErrorCode is not null)
            return new VnPayIpnResult(validation.ErrorCode, validation.ErrorMessage!);

        var intent = validation.Intent!;
        var payload = JsonSerializer.Serialize(values);
        if (!IsSuccessful(values))
        {
            await RecordFailedAttemptAsync(intent, payload, PaymentFinalizationSource.Ipn, ct);
            return new VnPayIpnResult("00", "Confirm Success");
        }

        var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(
            intent.Id, values.GetValueOrDefault("vnp_TransactionNo"), payload,
            PaymentFinalizationSource.Ipn, ct);
        return new VnPayIpnResult(finalized.Code, finalized.Message);
    }

    public async Task<VnPayReturnResult> ProcessReturnAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct = default)
    {
        if (!vnPay.VerifyCallback(values, options.Value))
            return new VnPayReturnResult(BuildPaymentResultUrl(
                options.Value.CustomerWebUrl, null, false));

        var validation = await FindAndValidateIntentAsync(values, ct);
        var intent = validation.Intent;
        var success = false;
        if (validation.ErrorCode is null && intent is not null)
        {
            var payload = JsonSerializer.Serialize(values);
            if (IsSuccessful(values))
            {
                var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(
                    intent.Id, values.GetValueOrDefault("vnp_TransactionNo"), payload,
                    PaymentFinalizationSource.ReturnFallback, ct);
                success = finalized.Succeeded;
            }
            else
            {
                await RecordFailedAttemptAsync(
                    intent, payload, PaymentFinalizationSource.ReturnFallback, ct);
            }
        }

        return new VnPayReturnResult(BuildPaymentResultUrl(
            options.Value.CustomerWebUrl, intent?.BookingId, success));
    }

    private async Task<IntentValidation> FindAndValidateIntentAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct)
    {
        if (!values.TryGetValue("vnp_TxnRef", out var orderRef) ||
            !values.TryGetValue("vnp_Amount", out var amountText) ||
            !values.ContainsKey("vnp_ResponseCode"))
            return new(null, "94", "Invalid payload");

        var intent = await paymentsDb.PaymentIntents.SingleOrDefaultAsync(
            x => x.Provider == "VNPAY" && x.ProviderOrderRef == orderRef, ct);
        if (intent is null) return new(null, "01", "Order not found");
        if (!long.TryParse(amountText, NumberStyles.None, CultureInfo.InvariantCulture,
                out var rawAmount) || rawAmount != checked(intent.Amount * 100))
            return new(intent, "04", "Invalid amount");
        return new(intent, null, null);
    }

    private async Task RecordFailedAttemptAsync(
        PaymentIntent intent, string payload, PaymentFinalizationSource source, CancellationToken ct)
    {
        Guid? messageId = null;
        await using (var tx = await paymentsDb.Database.BeginTransactionAsync(ct))
        {
            var locked = await paymentsDb.PaymentIntents.FromSqlInterpolated(
                    $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (locked is null || locked.Status is not ("CREATED" or "PENDING"))
            {
                await tx.CommitAsync(ct);
                return;
            }

            var failed = locked.MarkFailed(payload, source.ToString());
            if (failed.IsFailure) return;
            var message = OutboxMessage.Create(
                new PaymentFailed(locked.BookingId, locked.Id, source.ToString()));
            paymentsDb.OutboxMessages.Add(message);
            messageId = message.Id;
            await paymentsDb.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }

        await outbox.DispatchAsync(messageId!.Value, ct);

        await notifications.NotifyAsync(new UserNotificationMessage(
            intent.CustomerId, "PAYMENT", "Thanh toán chưa thành công",
            "Giao dịch chưa hoàn tất. Bạn có thể mở booking để thử lại.",
            new Dictionary<string, string>
            {
                ["bookingId"] = intent.BookingId.ToString(),
                ["status"] = "payment_failed",
                ["deepLink"] = $"/bookings/{intent.BookingId}"
            }), ct);
    }

    private static bool IsSuccessful(IReadOnlyDictionary<string, string> values) =>
        values.GetValueOrDefault("vnp_ResponseCode") == "00" &&
        values.GetValueOrDefault("vnp_TransactionStatus") == "00";

    private static string BuildPaymentResultUrl(string? customerWebUrl, Guid? bookingId, bool succeeded)
    {
        var query = $"result={(succeeded ? "success" : "failed")}";
        if (bookingId is not null)
            query += $"&bookingId={Uri.EscapeDataString(bookingId.Value.ToString())}";
        if (!string.IsNullOrWhiteSpace(customerWebUrl) &&
            Uri.TryCreate(customerWebUrl, UriKind.Absolute, out var baseUri) &&
            baseUri.Scheme is "http" or "https")
            return $"{baseUri.GetLeftPart(UriPartial.Authority)}{baseUri.AbsolutePath.TrimEnd('/')}/#/payment-result?{query}";
        return $"caresitter-customer:/payment-result?{query}";
    }

    private sealed record IntentValidation(
        PaymentIntent? Intent, string? ErrorCode, string? ErrorMessage);
}
