using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>Triển khai ký HMAC SHA512 theo chuẩn query string của VNPay.</summary>
public sealed class VNPayService(HttpClient httpClient) : IVNPayService
{
    private static TimeZoneInfo VietnamTimeZone =>
        TimeZoneInfo.FindSystemTimeZoneById(
            OperatingSystem.IsWindows() ? "SE Asia Standard Time" : "Asia/Ho_Chi_Minh");

    /// <summary>Tạo URL thanh toán đã ký cho một PaymentIntent.</summary>
    public string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options,
        string? bookingCustomerName = null)
    {
        if (string.IsNullOrWhiteSpace(options.TmnCode) || string.IsNullOrWhiteSpace(options.HashSecret))
            throw new InvalidOperationException("VNPay TmnCode và HashSecret chưa được cấu hình.");
        if (string.IsNullOrWhiteSpace(intent.ProviderOrderRef))
            throw new InvalidOperationException("PaymentIntent chua co ProviderOrderRef.");
        if (!DateTime.TryParseExact(intent.ProviderCreateDate, "yyyyMMddHHmmss",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var vietnamCreatedAt))
            throw new InvalidOperationException("PaymentIntent is missing the exact original VNPAY create date.");

        // Preserve the original wire timestamp across reload/retry; refund/querydr need
        // the EXACT vnp_CreateDate, not a newly generated URL timestamp.
        var timeoutMinutes = Math.Clamp(options.PaymentTimeoutMinutes, 5, 60);
        var values = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Version"] = options.Version,
            ["vnp_Command"] = "pay",
            ["vnp_TmnCode"] = options.TmnCode,
            ["vnp_Amount"] = checked(intent.Amount * 100).ToString(CultureInfo.InvariantCulture),
            ["vnp_CreateDate"] = intent.ProviderCreateDate,
            ["vnp_ExpireDate"] = vietnamCreatedAt.AddMinutes(timeoutMinutes).ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
            ["vnp_CurrCode"] = intent.Currency,
            ["vnp_IpAddr"] = "127.0.0.1",
            ["vnp_Locale"] = options.Locale,
            // VNPay already displays the amount separately. Describe the payer
            // clearly and never expose a booking GUID in the customer-facing text.
            ["vnp_OrderInfo"] = BuildOrderInfo(bookingCustomerName),
            ["vnp_OrderType"] = options.OrderType,
            ["vnp_ReturnUrl"] = options.ReturnUrl,
            ["vnp_TxnRef"] = intent.ProviderOrderRef
        };

        var hashData = BuildQuery(values);
        var secureHash = ComputeHash(hashData, options.HashSecret);
        return $"{options.PaymentUrl}?{hashData}&vnp_SecureHash={secureHash}";
    }

    private static string BuildOrderInfo(string? bookingCustomerName)
    {
        var name = string.IsNullOrWhiteSpace(bookingCustomerName)
            ? "CareSitter"
            : bookingCustomerName.Trim();
        return $"Thanh toán đơn hàng của khách hàng {name}";
    }

    /// <summary>Kiểm tra chữ ký callback bằng so sánh constant-time.</summary>
    public bool VerifyCallback(IReadOnlyDictionary<string, string> values, VNPayOptions options)
    {
        if (!values.TryGetValue("vnp_SecureHash", out var receivedHash) || string.IsNullOrWhiteSpace(receivedHash))
            return false;

        var hashValues = values
            .Where(x => x.Key.StartsWith("vnp_", StringComparison.OrdinalIgnoreCase)
                && !x.Key.Equals("vnp_SecureHash", StringComparison.OrdinalIgnoreCase)
                && !x.Key.Equals("vnp_SecureHashType", StringComparison.OrdinalIgnoreCase))
            .ToDictionary(x => x.Key, x => x.Value, StringComparer.Ordinal);
        var expectedHash = ComputeHash(BuildQuery(new SortedDictionary<string, string>(hashValues)), options.HashSecret);
        var expectedBytes = Encoding.ASCII.GetBytes(expectedHash);
        var receivedBytes = Encoding.ASCII.GetBytes(receivedHash.ToUpperInvariant());
        return expectedBytes.Length == receivedBytes.Length
            && CryptographicOperations.FixedTimeEquals(expectedBytes, receivedBytes);
    }

    public async Task<VNPayQueryResult> QueryTransactionAsync(
        PaymentIntent intent, VNPayOptions options, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(options.TmnCode) || string.IsNullOrWhiteSpace(options.HashSecret))
            throw new InvalidOperationException("VNPay TmnCode và HashSecret chưa được cấu hình.");
        if (string.IsNullOrWhiteSpace(options.QueryUrl))
            throw new InvalidOperationException("VNPay QueryUrl chưa được cấu hình.");
        if (string.IsNullOrWhiteSpace(intent.ProviderOrderRef))
            throw new InvalidOperationException("PaymentIntent chua co vnp_TxnRef.");

        var now = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, VietnamTimeZone);
        if (!DateTime.TryParseExact(intent.ProviderCreateDate, "yyyyMMddHHmmss",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out _))
            return new(VNPayQueryState.Unknown, null, "MISSING_ORIGINAL_CREATE_DATE", null,
                "{}", "Legacy payment requires provider-assisted reconciliation of its original create date.");
        var transactionDate = intent.ProviderCreateDate;
        var requestId = Guid.NewGuid().ToString("N");
        var createDate = now.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
        const string command = "querydr";
        var orderInfo = $"Doi soat giao dịch {intent.ProviderOrderRef}";
        const string ipAddress = "127.0.0.1";
        var hashData = string.Join('|', requestId, options.Version, command, options.TmnCode,
            intent.ProviderOrderRef, transactionDate, createDate, ipAddress, orderInfo);

        var body = new Dictionary<string, string>
        {
            ["vnp_RequestId"] = requestId,
            ["vnp_Version"] = options.Version,
            ["vnp_Command"] = command,
            ["vnp_TmnCode"] = options.TmnCode,
            ["vnp_TxnRef"] = intent.ProviderOrderRef,
            ["vnp_OrderInfo"] = orderInfo,
            ["vnp_TransactionDate"] = transactionDate,
            ["vnp_CreateDate"] = createDate,
            ["vnp_IpAddr"] = ipAddress,
            ["vnp_SecureHash"] = ComputeHash(hashData, options.HashSecret)
        };

        using var response = await httpClient.PostAsJsonAsync(options.QueryUrl, body, ct);
        var raw = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            return new(VNPayQueryState.Unknown, null, ((int)response.StatusCode).ToString(),
                null, raw, "VNPay Query API tra ve HTTP loi.");

        try
        {
            using var json = System.Text.Json.JsonDocument.Parse(raw);
            var root = json.RootElement;
            string? Get(string name) => root.TryGetProperty(name, out var value) ? value.ToString() : null;
            var responseCode = Get("vnp_ResponseCode") ?? "99";
            var transactionStatus = Get("vnp_TransactionStatus");
            var state = responseCode switch
            {
                "00" when transactionStatus == "00" => VNPayQueryState.Succeeded,
                "00" when transactionStatus == "01" => VNPayQueryState.Processing,
                "00" when transactionStatus is "02" or "04" or "05" or "06" or "07" or "09"
                    => VNPayQueryState.Failed,
                "91" => VNPayQueryState.NotFound,
                _ => VNPayQueryState.Unknown
            };
            return new(state, Get("vnp_TransactionNo"), responseCode, transactionStatus,
                raw, Get("vnp_Message") ?? Get("message"));
        }
        catch (System.Text.Json.JsonException)
        {
            return new(VNPayQueryState.Unknown, null, "INVALID_RESPONSE", null, raw,
                "VNPay Query API tra ve du lieu khong hop le.");
        }
    }

    /// <summary>Mã hóa và sắp xếp các tham số theo quy tắc VNPay.</summary>
    private static string BuildQuery(IReadOnlyDictionary<string, string> values) =>
        string.Join("&", values.Where(x => !string.IsNullOrEmpty(x.Value))
            .OrderBy(x => x.Key, StringComparer.Ordinal)
            .Select(x => $"{WebUtility.UrlEncode(x.Key)}={WebUtility.UrlEncode(x.Value)}"));

    /// <summary>Tạo chữ ký HMAC SHA512 ở dạng hexadecimal uppercase.</summary>
    private static string ComputeHash(string data, string secret)
    {
        using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(data)));
    }
}
