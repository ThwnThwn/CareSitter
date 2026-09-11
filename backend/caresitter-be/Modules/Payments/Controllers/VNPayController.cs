using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.SignalR;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;
using System.Text.Json.Serialization;

namespace CareSitter.Modules.Payments.Controllers;

/// <summary>Nhận IPN và Return URL từ VNPay Sandbox.</summary>
[ApiController]
[AllowAnonymous]
public sealed class VNPayController(
    PaymentsDbContext paymentsDb,
    BookingDbContext bookingDb,
    IWalletService wallet,
    IVNPayService vnPay,
    IOptions<VNPayOptions> options,
    BookingSyncService bookingSync,
    IMatchingService matching,
    IHubContext<CareTrackingHub> hub) : ControllerBase
{
    /// <summary>Xử lý IPN VNPay, bảo đảm callback lặp lại không tạo giao dịch thứ hai.</summary>
    [HttpGet("api/v1/payments/vnpay/ipn")]
    public async Task<IActionResult> Ipn(CancellationToken ct)
    {
        var values = Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString(), StringComparer.Ordinal);
        if (!vnPay.VerifyCallback(values, options.Value))
            return Ok(VnPayResponse("97", "Invalid signature"));

        if (!values.TryGetValue("vnp_TxnRef", out var orderRef) ||
            !values.TryGetValue("vnp_Amount", out var amountText) ||
            !values.TryGetValue("vnp_ResponseCode", out var responseCode))
            return Ok(VnPayResponse("94", "Invalid payload"));

        var intent = await paymentsDb.PaymentIntents
            .SingleOrDefaultAsync(x => x.Provider == "VNPAY" && x.ProviderOrderRef == orderRef, ct);
        if (intent is null)
            return Ok(VnPayResponse("01", "Order not found"));

        if (!long.TryParse(amountText, NumberStyles.None, CultureInfo.InvariantCulture, out var rawAmount) ||
            rawAmount != checked(intent.Amount * 100))
            return Ok(VnPayResponse("04", "Invalid amount"));

        var transactionId = values.GetValueOrDefault("vnp_TransactionNo");
        // response_payload là jsonb; không lưu nguyên query string vì PostgreSQL sẽ từ chối.
        var payload = JsonSerializer.Serialize(values);

        if (responseCode != "00" || values.GetValueOrDefault("vnp_TransactionStatus") != "00")
        {
            if (intent.Status is not "SUCCEEDED" and not "FAILED")
            {
                intent.MarkFailed(payload);
                await paymentsDb.SaveChangesAsync(ct);
                await ReleaseSlotHoldAsync(intent.BookingId, ct);
            }
            return Ok(VnPayResponse("00", "Confirm Success"));
        }

        var finalizeResult = await FinalizeSuccessfulPaymentAsync(
            intent, transactionId, payload, ct);
        return Ok(VnPayResponse(finalizeResult.Code, finalizeResult.Message));
    }

    /// <summary>Hiển thị trạng thái giao dịch khi người dùng quay lại từ VNPay.</summary>
    [HttpGet("api/v1/payments/vnpay/return")]
    public async Task<IActionResult> Return(CancellationToken ct)
    {
        var values = Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString(), StringComparer.Ordinal);
        if (!vnPay.VerifyCallback(values, options.Value))
            return Content(ReturnHtml(false, "Thanh toán chưa được xác thực.", values), "text/html");

        var responseCode = values.GetValueOrDefault("vnp_ResponseCode");
        var transactionStatus = values.GetValueOrDefault("vnp_TransactionStatus");
        var success = responseCode == "00" && transactionStatus == "00";
        if (success && values.TryGetValue("vnp_TxnRef", out var orderRef))
        {
            var intent = await paymentsDb.PaymentIntents
                .SingleOrDefaultAsync(x => x.Provider == "VNPAY" && x.ProviderOrderRef == orderRef, ct);
            if (intent is not null && long.TryParse(values.GetValueOrDefault("vnp_Amount"),
                    NumberStyles.None, CultureInfo.InvariantCulture, out var rawAmount) &&
                rawAmount == checked(intent.Amount * 100))
            {
                var result = await FinalizeSuccessfulPaymentAsync(
                    intent,
                    values.GetValueOrDefault("vnp_TransactionNo"),
                    JsonSerializer.Serialize(values),
                    ct);
                success = result.Code == "00";
            }
            else
            {
                success = false;
            }
        }

        var message = responseCode == "00"
            ? success
                ? "Thanh toán thành công. Bạn có thể quay lại ứng dụng CareSitter."
                : "VNPay báo thanh toán thành công nhưng hệ thống chưa chốt được đơn. Vui lòng mở lại ứng dụng sau ít giây."
            : "Thanh toán chưa thành công. Bạn có thể quay lại ứng dụng để thử lại.";
        return Content(ReturnHtml(success, message, values), "text/html");
    }

    /// <summary>Chốt giao dịch thành công một cách idempotent cho cả IPN và Return fallback.</summary>
    private async Task<(string Code, string Message)> FinalizeSuccessfulPaymentAsync(
        PaymentIntent intent, string? transactionId, string? payload, CancellationToken ct)
    {
        if (intent.Status is not "SUCCEEDED")
        {
            var markResult = intent.MarkSucceeded(transactionId, payload);
            if (markResult.IsFailure && intent.Status is not "SUCCEEDED")
                return ("99", "Could not mark payment succeeded");
            await paymentsDb.SaveChangesAsync(ct);
        }

        var escrowResult = await wallet.LockEscrowAsync(intent.BookingId, intent.Amount,
            $"escrow-lock:{intent.BookingId}", ct);
        if (escrowResult.IsFailure)
            return ("99", "Could not lock escrow");

        var booking = await bookingDb.Bookings.SingleOrDefaultAsync(x => x.Id == intent.BookingId, ct);
        if (booking is null)
            return ("01", "Booking not found");

        var changedToConfirmed = false;
        if (booking.Status == BookingStatus.PendingPayment)
        {
            var confirmResult = booking.ConfirmPayment();
            if (confirmResult.IsFailure)
                return ("99", "Could not confirm booking");

            bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.PaymentConfirmed);
            changedToConfirmed = true;
        }

        var hold = await bookingDb.CaregiverSlotHolds
            .SingleOrDefaultAsync(x => x.BookingId == intent.BookingId && x.Status == "HELD", ct);
        hold?.Commit();
        await bookingDb.SaveChangesAsync(ct);

        if (changedToConfirmed)
        {
            await PublishCustomerSyncEventAsync(booking, ct);
        }

        // Retry cả khi request trước đã crash sau SaveChanges nhưng trước matching.
        if (booking.Status == BookingStatus.Confirmed)
            await matching.OfferTopCandidatesAsync(booking.Id, ct);

        return ("00", "Confirm Success");
    }

    /// <summary>Phát tín hiệu để customer đồng bộ booking sau khi thanh toán chốt thành công.</summary>
    private async Task PublishCustomerSyncEventAsync(BookingEntity booking, CancellationToken ct)
    {
        var cursor = await bookingSync.GetCurrentCursorAsync(booking.CustomerId, ct);
        await hub.Clients.Group(CareTrackingHub.CustomerGroup(booking.CustomerId))
            .SendAsync("BookingListSync", new { bookingId = booking.Id, booking.SyncVersion, cursor }, ct);
    }

    /// <summary>Tạo trang kết quả thanh toán responsive, không phụ thuộc frontend hoặc asset ngoài.</summary>
    private static string ReturnHtml(bool success, string message, IReadOnlyDictionary<string, string> values)
    {
        var bookingId = ExtractBookingId(values.GetValueOrDefault("vnp_OrderInfo"));
        var transactionNo = values.GetValueOrDefault("vnp_TransactionNo");
        var orderRef = values.GetValueOrDefault("vnp_TxnRef");
        var responseCode = values.GetValueOrDefault("vnp_ResponseCode");
        var title = success ? "Thanh toán thành công" : "Thanh toán chưa hoàn tất";
        var lead = success
            ? "Giao dịch của bạn đã được ghi nhận và booking đang được đồng bộ."
            : message;
        var icon = success
            ? "<svg viewBox='0 0 48 48' aria-hidden='true'><path d='m14 25 7 7 14-15'/></svg>"
            : "<svg viewBox='0 0 48 48' aria-hidden='true'><path d='M24 14v12'/><path d='M24 34h.01'/></svg>";
        var action = success
            ? $"<a class='button primary' href='caresitter://booking/{Html(bookingId)}' onclick='return openCareSitter(event)'>Mở CareSitter</a>"
            : "<button class='button primary' type='button' onclick='goBack()'>Quay lại thử lại</button>";

        return $$$"""
<!doctype html>
<html lang='vi'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{{{Html(title)}}} · CareSitter</title>
  <style>
    :root {{ color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; --ink:#173333; --muted:#5b7474; --primary:#00a94b; --primary-dark:#087d3c; --mint:#e5f7ed; --bg:#eef7f7; --line:#d5e8e8; --danger:#c93434; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; min-height:100vh; display:grid; place-items:center; padding:24px 16px; color:var(--ink); background:var(--bg); }}
    .page {{ width:min(100%, 480px); }}
    .brand {{ display:flex; align-items:center; gap:10px; margin:0 0 22px 4px; color:var(--primary-dark); font-size:20px; font-weight:750; letter-spacing:-.02em; }}
    .brand-mark {{ width:32px; height:32px; display:grid; place-items:center; border-radius:10px; color:white; background:var(--primary); font-size:18px; }}
    .panel {{ overflow:hidden; border:1px solid var(--line); border-radius:16px; background:#fff; box-shadow:0 6px 8px rgba(23,51,51,.08); }}
    .hero {{ padding:36px 28px 30px; text-align:center; }}
    .status-icon {{ width:72px; height:72px; display:grid; place-items:center; margin:0 auto 20px; border-radius:50%; color:var(--primary-dark); background:var(--mint); }}
    .status-icon.failed {{ color:var(--danger); background:#fdecec; }}
    .status-icon svg {{ width:40px; height:40px; fill:none; stroke:currentColor; stroke-linecap:round; stroke-linejoin:round; stroke-width:3.2; }}
    h1 {{ margin:0; font-size:25px; line-height:1.2; letter-spacing:-.02em; text-wrap:balance; }}
    .lead {{ max-width:36ch; margin:12px auto 0; color:var(--muted); font-size:15px; line-height:1.5; }}
    .details {{ padding:0 28px 26px; }}
    .detail-list {{ margin:0; padding:0; border-top:1px solid var(--line); }}
    .detail-row {{ display:flex; justify-content:space-between; gap:18px; padding:14px 0; border-bottom:1px solid var(--line); font-size:13px; }}
    .detail-row dt {{ color:var(--muted); }}
    .detail-row dd {{ max-width:62%; margin:0; overflow-wrap:anywhere; color:var(--ink); font-weight:650; text-align:right; }}
    .actions {{ display:grid; gap:10px; margin-top:24px; }}
    .button {{ min-height:48px; display:grid; place-items:center; border:0; border-radius:12px; font:inherit; font-size:15px; font-weight:700; text-decoration:none; cursor:pointer; }}
    .button.primary {{ color:#fff; background:var(--primary); }}
    .button.primary:hover {{ background:var(--primary-dark); }}
    .button.secondary {{ color:var(--primary-dark); background:var(--mint); }}
    .note {{ margin:18px 0 0; color:var(--muted); font-size:12px; line-height:1.5; text-align:center; }}
    @media (max-width:420px) {{ .hero {{ padding:30px 20px 24px; }} .details {{ padding:0 20px 22px; }} h1 {{ font-size:23px; }} }}
    @media (prefers-reduced-motion:no-preference) {{ .status-icon svg {{ animation:draw .45s ease-out both; }} @keyframes draw {{ from {{ transform:scale(.75); opacity:.2; }} to {{ transform:scale(1); opacity:1; }} }} }}
  </style>
</head>
<body>
  <main class='page'>
    <div class='brand'><span class='brand-mark'>♥</span><span>CareSitter</span></div>
    <section class='panel' aria-live='polite'>
      <div class='hero'>
        <div class='status-icon {{{(success ? "" : "failed")}}}'>{{{icon}}}</div>
        <h1>{{{Html(title)}}}</h1>
        <p class='lead'>{{{Html(lead)}}}</p>
      </div>
      <div class='details'>
        <dl class='detail-list'>
          {{{(success ? $"<div class='detail-row'><dt>Mã giao dịch</dt><dd>{Html(transactionNo)}</dd></div>" : $"<div class='detail-row'><dt>Mã phản hồi</dt><dd>{Html(responseCode)}</dd></div>")}}}
          <div class='detail-row'><dt>Mã booking</dt><dd>{{{Html(bookingId)}}}</dd></div>
          <div class='detail-row'><dt>Mã đơn thanh toán</dt><dd>{{{Html(orderRef)}}}</dd></div>
        </dl>
        <div class='actions'>{{{action}}}<button class='button secondary' type='button' onclick='goBack()'>Quay lại trang trước</button></div>
        <p class='note'>{{{(success ? "Bạn có thể đóng trang này sau khi mở lại CareSitter." : "Nếu số tiền đã bị trừ, vui lòng giữ mã giao dịch và liên hệ hỗ trợ.")}}}</p>
      </div>
    </section>
  </main>
  <script>
    function goBack() {{ if (history.length > 1) history.back(); else location.href = '/'; }}
    function openCareSitter(event) {{ setTimeout(function () {{ if (document.visibilityState === 'visible') goBack(); }}, 900); return true; }}
  </script>
</body>
</html>
""";
    }

    /// <summary>Lấy booking id từ nội dung đơn hàng VNPay để hiển thị và deep-link.</summary>
    private static string ExtractBookingId(string? orderInfo)
    {
        var match = Regex.Match(orderInfo ?? string.Empty,
            @"[0-9a-fA-F]{{8}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{12}}");
        return match.Success ? match.Value : "—";
    }

    /// <summary>Escape dữ liệu callback trước khi đưa vào HTML response.</summary>
    private static string Html(string? value) =>
        System.Net.WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(value) ? "—" : value);

    /// <summary>Tạo response ngắn gọn theo format IPN của VNPay.</summary>
    private static VnPayIpnResponse VnPayResponse(string code, string message) =>
        new(code, message);

    /// <summary>Giải phóng slot đang giữ khi VNPay trả về trạng thái thất bại.</summary>
    private async Task ReleaseSlotHoldAsync(Guid bookingId, CancellationToken ct)
    {
        var hold = await bookingDb.CaregiverSlotHolds
            .SingleOrDefaultAsync(x => x.BookingId == bookingId && x.Status == "HELD", ct);
        if (hold is null) return;
        hold.Release();
        await bookingDb.SaveChangesAsync(ct);
    }

    /// <summary>DTO giữ nguyên tên field bắt buộc trong response IPN của VNPay.</summary>
    private sealed record VnPayIpnResponse(
        [property: JsonPropertyName("RspCode")] string RspCode,
        [property: JsonPropertyName("Message")] string Message);
}
