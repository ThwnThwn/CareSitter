using System.Globalization;
using System.Net;
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
    public string Version { get; set; } = "2.1.0";
    public string Locale { get; set; } = "vn";
    public string OrderType { get; set; } = "other";
}

/// <summary>Hợp đồng tạo URL và xác minh chữ ký callback của VNPay.</summary>
public interface IVNPayService
{
    string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options);
    bool VerifyCallback(IReadOnlyDictionary<string, string> values, VNPayOptions options);
}

/// <summary>Triển khai ký HMAC SHA512 theo chuẩn query string của VNPay.</summary>
public sealed class VNPayService : IVNPayService
{
    /// <summary>Tạo URL thanh toán đã ký cho một PaymentIntent.</summary>
    public string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.TmnCode) || string.IsNullOrWhiteSpace(options.HashSecret))
            throw new InvalidOperationException("VNPay TmnCode va HashSecret chua duoc cau hinh.");
        if (string.IsNullOrWhiteSpace(intent.ProviderOrderRef))
            throw new InvalidOperationException("PaymentIntent chua co ProviderOrderRef.");

        var values = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Version"] = options.Version,
            ["vnp_Command"] = "pay",
            ["vnp_TmnCode"] = options.TmnCode,
            ["vnp_Amount"] = checked(intent.Amount * 100).ToString(CultureInfo.InvariantCulture),
            ["vnp_CreateDate"] = DateTime.UtcNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture),
            ["vnp_CurrCode"] = intent.Currency,
            ["vnp_IpAddr"] = "127.0.0.1",
            ["vnp_Locale"] = options.Locale,
            ["vnp_OrderInfo"] = $"Thanh toan booking {intent.BookingId}",
            ["vnp_OrderType"] = options.OrderType,
            ["vnp_ReturnUrl"] = options.ReturnUrl,
            ["vnp_TxnRef"] = intent.ProviderOrderRef
        };

        var hashData = BuildQuery(values);
        var secureHash = ComputeHash(hashData, options.HashSecret);
        return $"{options.PaymentUrl}?{hashData}&vnp_SecureHash={secureHash}";
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
