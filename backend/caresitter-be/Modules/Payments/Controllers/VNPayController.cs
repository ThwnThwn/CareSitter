using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Controllers;

/// <summary>
/// Nhan IPN/Return tu VNPay. Controller chi xu ly protocol va chuyen huong;
/// giao dien ket qua thanh toan nam hoan toan o customer frontend.
/// </summary>
[ApiController]
[AllowAnonymous]
public sealed class VNPayController(
    PaymentsDbContext paymentsDb,
    BookingDbContext bookingDb,
    IVNPayService vnPay,
    IPaymentFinalizationService finalizer,
    IOptions<VNPayOptions> options,
    IUserNotificationService notifications) : ControllerBase
{
    [HttpGet("api/v1/payments/vnpay/ipn")]
    public async Task<IActionResult> Ipn(CancellationToken ct)
    {
        var values = CallbackValues();
        if (!vnPay.VerifyCallback(values, options.Value))
            return Ok(VnPayResponse("97", "Invalid signature"));

        var validation = await FindAndValidateIntentAsync(values, ct);
        if (validation.ErrorCode is not null)
            return Ok(VnPayResponse(validation.ErrorCode, validation.ErrorMessage!));

        var intent = validation.Intent!;
        var payload = JsonSerializer.Serialize(values);
        if (!IsSuccessful(values))
        {
            await RecordFailedAttemptAsync(intent, payload, PaymentFinalizationSource.Ipn, ct);
            return Ok(VnPayResponse("00", "Confirm Success"));
        }

        var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(
            intent.Id, values.GetValueOrDefault("vnp_TransactionNo"), payload,
            PaymentFinalizationSource.Ipn, ct);
        return Ok(VnPayResponse(finalized.Code, finalized.Message));
    }

    [HttpGet("api/v1/payments/vnpay/return")]
    public async Task<IActionResult> Return(CancellationToken ct)
    {
        var values = CallbackValues();
        if (!vnPay.VerifyCallback(values, options.Value))
            return Redirect(BuildPaymentResultUrl(options.Value.CustomerWebUrl, null, false));

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
                await RecordFailedAttemptAsync(intent, payload,
                    PaymentFinalizationSource.ReturnFallback, ct);
            }
        }

        return Redirect(BuildPaymentResultUrl(
            options.Value.CustomerWebUrl, intent?.BookingId, success));
    }

    private Dictionary<string, string> CallbackValues() =>
        Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString(), StringComparer.Ordinal);

    private async Task<IntentValidation> FindAndValidateIntentAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct)
    {
        if (!values.TryGetValue("vnp_TxnRef", out var orderRef) ||
            !values.TryGetValue("vnp_Amount", out var amountText) ||
            !values.ContainsKey("vnp_ResponseCode"))
            return new(null, "94", "Invalid payload");

        var intent = await paymentsDb.PaymentIntents
            .SingleOrDefaultAsync(x => x.Provider == "VNPAY" && x.ProviderOrderRef == orderRef, ct);
        if (intent is null)
            return new(null, "01", "Order not found");

        if (!long.TryParse(amountText, NumberStyles.None, CultureInfo.InvariantCulture, out var rawAmount) ||
            rawAmount != checked(intent.Amount * 100))
            return new(intent, "04", "Invalid amount");

        return new(intent, null, null);
    }

    private async Task RecordFailedAttemptAsync(PaymentIntent intent, string payload,
        PaymentFinalizationSource source, CancellationToken ct)
    {
        await using var tx = await bookingDb.Database.BeginTransactionAsync(ct);
        var booking = await bookingDb.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {intent.BookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null || booking.Status is not
            (BookingStatus.PendingPayment or BookingStatus.PaymentReconciliationPending))
            return;

        var updated = await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'FAILED', response_payload = CAST({{payload}} AS jsonb),
                finalized_source = {{source.ToString()}}, next_reconciliation_at = NULL,
                updated_at = now()
            WHERE id = {{intent.Id}} AND status IN ('CREATED', 'PENDING')
            """, ct);
        if (updated == 0) return;

        var hold = await bookingDb.CaregiverSlotHolds
            .SingleOrDefaultAsync(x => x.BookingId == intent.BookingId && x.Status == "HELD", ct);
        hold?.Release();
        if (hold is not null) await bookingDb.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        await notifications.NotifyAsync(new UserNotificationMessage(
            booking.CustomerId, "PAYMENT", "Thanh toán chưa thành công",
            "Giao dịch chưa hoàn tất. Bạn có thể mở booking để thử lại.",
            new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(),
                ["status"] = "payment_failed",
                ["deepLink"] = $"/bookings/{booking.Id}"
            }), ct);
    }

    private static bool IsSuccessful(IReadOnlyDictionary<string, string> values) =>
        values.GetValueOrDefault("vnp_ResponseCode") == "00" &&
        values.GetValueOrDefault("vnp_TransactionStatus") == "00";

    private static string BuildPaymentResultUrl(string? customerWebUrl, Guid? bookingId, bool succeeded)
    {
        var result = succeeded ? "success" : "failed";
        var query = $"result={result}";
        if (bookingId is not null)
            query += $"&bookingId={Uri.EscapeDataString(bookingId.Value.ToString())}";

        if (!string.IsNullOrWhiteSpace(customerWebUrl) &&
            Uri.TryCreate(customerWebUrl, UriKind.Absolute, out var baseUri) &&
            baseUri.Scheme is "http" or "https")
        {
            return $"{baseUri.GetLeftPart(UriPartial.Authority)}{baseUri.AbsolutePath.TrimEnd('/')}/#/payment-result?{query}";
        }

        // Dung path-based custom URI de Flutter/GoRouter nhan dung /payment-result.
        return $"caresitter-customer:/payment-result?{query}";
    }

    private static VnPayIpnResponse VnPayResponse(string code, string message) => new(code, message);

    private sealed record IntentValidation(PaymentIntent? Intent, string? ErrorCode, string? ErrorMessage);
    private sealed record VnPayIpnResponse(
        [property: JsonPropertyName("RspCode")] string RspCode,
        [property: JsonPropertyName("Message")] string Message);
}
