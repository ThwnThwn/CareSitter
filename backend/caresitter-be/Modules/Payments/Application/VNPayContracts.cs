using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Application;

public sealed class VNPayOptions
{
    public const string SectionName = "Payments:VNPay";
    public string TmnCode { get; set; } = string.Empty;
    public string HashSecret { get; set; } = string.Empty;
    public string PaymentUrl { get; set; } = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
    public string ReturnUrl { get; set; } = string.Empty;
    public string IpnUrl { get; set; } = string.Empty;
    public string CustomerWebUrl { get; set; } = string.Empty;
    public int PaymentTimeoutMinutes { get; set; } = 15;
    public int BookingPaymentDeadlineMinutes { get; set; } = 30;
    public string QueryUrl { get; set; } = "https://sandbox.vnpayment.vn/merchant_webapi/api/transaction";
    public int MaxReconciliationAttempts { get; set; } = 3;
    public int ReconciliationWindowMinutes { get; set; } = 10;
    public string Version { get; set; } = "2.1.0";
    public string Locale { get; set; } = "vn";
    public string OrderType { get; set; } = "other";
}

public interface IVNPayService
{
    string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options,
        string? bookingCustomerName = null);
    bool VerifyCallback(IReadOnlyDictionary<string, string> values, VNPayOptions options);
    Task<VNPayQueryResult> QueryTransactionAsync(PaymentIntent intent, VNPayOptions options,
        CancellationToken ct = default);
}

public enum VNPayQueryState { Succeeded, Processing, Failed, NotFound, Unknown }
public sealed record VNPayQueryResult(VNPayQueryState State, string? TransactionId,
    string ResponseCode, string? TransactionStatus, string RawPayload, string? Message);
