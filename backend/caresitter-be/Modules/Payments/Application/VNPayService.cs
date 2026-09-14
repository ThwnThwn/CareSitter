using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Application;

/// <summary>Cấu hình kết nối VNPay Sandbox và callback public của môi trường hiện tại.</summary>
public sealed class VNPayOptions
{
    public const string SectionName = "Payments:VNPay";
    public string TmnCode { get; set; } = string.Empty;
    public string HashSecret { get; set; } = string.Empty;
    public string PaymentUrl { get; set; } = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
    public string ReturnUrl { get; set; } = string.Empty;
    public string IpnUrl { get; set; } = string.Empty;
    /// <summary>
    /// Base URL cua Flutter Web customer, vi du https://app.caresitter.vn.
    /// De trong thi trang return dung deep-link mobile caresitter-customer://.
    /// </summary>
    public string CustomerWebUrl { get; set; } = string.Empty;
    /// <summary>Thoi gian tối đa cho mot URL VNPay truoc khi phai tao attempt moi.</summary>
    public int PaymentTimeoutMinutes { get; set; } = 15;
    /// <summary>
    /// Thoi han tong the cua booking de khach co the tao nhieu lan thanh toan.
    /// Gia tri nay phai lon hon hoac bang PaymentTimeoutMinutes.
    /// </summary>
    public int BookingPaymentDeadlineMinutes { get; set; } = 30;
    public string QueryUrl { get; set; } = "https://sandbox.vnpayment.vn/merchant_webapi/api/transaction";
    public int MaxReconciliationAttempts { get; set; } = 3;
    public int ReconciliationWindowMinutes { get; set; } = 10;
    public string Version { get; set; } = "2.1.0";
    public string Locale { get; set; } = "vn";
    public string OrderType { get; set; } = "other";
}

/// <summary>Hợp đồng tạo URL và xác minh chữ ký callback của VNPay.</summary>
public interface IVNPayService
{
    string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options,
        string? beneficiaryName = null);
    bool VerifyCallback(IReadOnlyDictionary<string, string> values, VNPayOptions options);
    Task<VNPayQueryResult> QueryTransactionAsync(PaymentIntent intent, VNPayOptions options,
        CancellationToken ct = default);
}

public enum VNPayQueryState { Succeeded, Processing, Failed, NotFound, Unknown }
public sealed record VNPayQueryResult(VNPayQueryState State, string? TransactionId,
    string ResponseCode, string? TransactionStatus, string RawPayload, string? Message);

/// <summary>Triển khai ký HMAC SHA512 theo chuẩn query string của VNPay.</summary>
public sealed class VNPayService(HttpClient httpClient) : IVNPayService
{
    private static TimeZoneInfo VietnamTimeZone =>
        TimeZoneInfo.FindSystemTimeZoneById(
            OperatingSystem.IsWindows() ? "SE Asia Standard Time" : "Asia/Ho_Chi_Minh");

    /// <summary>Tạo URL thanh toán đã ký cho một PaymentIntent.</summary>
    public string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options,
        string? beneficiaryName = null)
    {
        if (string.IsNullOrWhiteSpace(options.TmnCode) || string.IsNullOrWhiteSpace(options.HashSecret))
            throw new InvalidOperationException("VNPay TmnCode và HashSecret chưa được cấu hình.");
        if (string.IsNullOrWhiteSpace(intent.ProviderOrderRef))
            throw new InvalidOperationException("PaymentIntent chua co ProviderOrderRef.");

        // VNPay quy dinh vnp_CreateDate/vnp_ExpireDate theo GMT+7, khong phai UTC.
        // Dung chung mot moc thoi gian de tranh lech giay giua hai tham so.
        var vietnamNow = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, VietnamTimeZone);
        var timeoutMinutes = Math.Clamp(options.PaymentTimeoutMinutes, 5, 60);
        var values = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Version"] = options.Version,
            ["vnp_Command"] = "pay",
            ["vnp_TmnCode"] = options.TmnCode,
            ["vnp_Amount"] = checked(intent.Amount * 100).ToString(CultureInfo.InvariantCulture),
            ["vnp_CreateDate"] = vietnamNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
            ["vnp_ExpireDate"] = vietnamNow.AddMinutes(timeoutMinutes).ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
            ["vnp_CurrCode"] = intent.Currency,
            ["vnp_IpAddr"] = "127.0.0.1",
            ["vnp_Locale"] = options.Locale,
            // VNPay already displays the amount separately. Keep the order info
            // short, human-readable, and based on the public payment reference
            // instead of exposing a long internal booking GUID.
            ["vnp_OrderInfo"] = BuildOrderInfo(intent, beneficiaryName),
            ["vnp_OrderType"] = options.OrderType,
            ["vnp_ReturnUrl"] = options.ReturnUrl,
            ["vnp_TxnRef"] = intent.ProviderOrderRef
        };

        var hashData = BuildQuery(values);
        var secureHash = ComputeHash(hashData, options.HashSecret);
        return $"{options.PaymentUrl}?{hashData}&vnp_SecureHash={secureHash}";
    }

    private static string BuildOrderInfo(PaymentIntent intent, string? beneficiaryName)
    {
        var name = string.IsNullOrWhiteSpace(beneficiaryName)
            ? "Nguoi duoc cham soc"
            : beneficiaryName.Trim();
        // Keep the provider field compact and avoid exposing the internal booking GUID.
        return $"CareSitter - Thanh toan dich vu cham soc cua khach hang - " +
            $"Nguoi duoc cham soc: {name} - Ma don: {intent.ProviderOrderRef}";
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
        var transactionDate = TimeZoneInfo.ConvertTime(intent.CreatedAt, VietnamTimeZone)
            .ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
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
