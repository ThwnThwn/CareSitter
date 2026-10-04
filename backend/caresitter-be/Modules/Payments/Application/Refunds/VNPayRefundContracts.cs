using System.Globalization;
using System.Net;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed class VNPayRefundOptions
{
    public const string SectionName = "Payments:VNPayRefund";
    // Opt-in only. Registering the adapter must not enable money movement.
    public bool Enabled { get; set; }
    public string ApiUrl { get; set; } = string.Empty;
}

/// <summary>
/// An immutable full-refund wire snapshot. The workflow must persist this snapshot and
/// its unique request ID BEFORE submitting it. It must never blindly resubmit an
/// ambiguous request (including after process death).
/// </summary>
public sealed class VNPayFullRefundRequest
{
    private VNPayFullRefundRequest(PaymentIntent intent, string requestId, string merchantCode,
        string originalCreateDate, DateTimeOffset createdAt, string serverIpAddress)
    {
        PaymentIntentId = intent.Id;
        RequestId = requestId;
        MerchantCode = merchantCode;
        OrderReference = intent.ProviderOrderRef!;
        OriginalTransactionId = intent.ProviderTransactionId!;
        Amount = intent.Amount;
        OriginalCreateDate = originalCreateDate;
        CreateDate = FormatVietnamDate(createdAt);
        ServerIpAddress = serverIpAddress;
        OrderInfo = $"CareSitter full refund {requestId}";
    }

    public Guid PaymentIntentId { get; }
    public string RequestId { get; }
    public string MerchantCode { get; }
    public string OrderReference { get; }
    public string OriginalTransactionId { get; }
    public long Amount { get; }
    public string OriginalCreateDate { get; }
    public string CreateDate { get; }
    public string ServerIpAddress { get; }
    public string OrderInfo { get; }

    /// <summary>Creates a request using the exact vnp_CreateDate sent in the original
    /// payment request, not vnp_PayDate and not a guess from local CreatedAt.</summary>
    public static Result<VNPayFullRefundRequest> Create(PaymentIntent intent,
        string requestId, string merchantCode, string originalCreateDate,
        DateTimeOffset createdAt, string serverIpAddress)
    {
        if (intent.Provider != "VNPAY" || intent.Status != "SUCCEEDED" || intent.Currency != "VND")
            return Invalid("Only a succeeded VNPAY/VND payment can be refunded.");
        // VNPAY accepts at most 12 digits AFTER the VND * 100 conversion.
        if (intent.Amount is <= 0 or > 9_999_999_999)
            return Invalid("The paid amount is outside the VNPAY refund range.");
        if (!IsAlphaNumeric(requestId, 1, 32) || !IsAlphaNumeric(merchantCode, 8, 8) ||
            !IsAlphaNumeric(intent.ProviderOrderRef, 1, 100) ||
            !IsNumeric(intent.ProviderTransactionId, 1, 15))
            return Invalid("Refund references are missing or invalid.");
        if (!IsDate(originalCreateDate) || originalCreateDate != intent.ProviderCreateDate ||
            string.CompareOrdinal(originalCreateDate, FormatVietnamDate(createdAt)) > 0)
            return Invalid("The exact original payment create date is required.");
        if (!IPAddress.TryParse(serverIpAddress, out _) || serverIpAddress.Length is < 7 or > 45)
            return Invalid("A valid API server IP address is required.");
        return new VNPayFullRefundRequest(intent, requestId, merchantCode,
            originalCreateDate, createdAt, serverIpAddress);
    }

    internal static bool IsAlphaNumeric(string? value, int min, int max) =>
        value is not null && value.Length >= min && value.Length <= max &&
        value.All(c => char.IsAsciiLetterOrDigit(c));

    internal static bool IsNumeric(string? value, int min, int max) =>
        value is not null && value.Length >= min && value.Length <= max &&
        value.All(c => char.IsAsciiDigit(c));

    internal static bool IsDate(string? value) => IsNumeric(value, 14, 14) &&
        DateTime.TryParseExact(value, "yyyyMMddHHmmss", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out _);

    internal static string FormatVietnamDate(DateTimeOffset time) =>
        time.ToOffset(TimeSpan.FromHours(7)).ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);

    private static Error Invalid(string message) => Error.Validation("refund.invalid_request", message);
}

public enum VNPayRefundState { Confirmed, Processing, Rejected, Unknown }

public sealed record VNPayRefundResult(VNPayRefundState State, string Code,
    string? ProviderResponseId = null, string? ProviderRefundId = null,
    string? TransactionStatus = null, string? RawPayload = null);

public interface IVNPayRefundGateway
{
    Task<VNPayRefundResult> SubmitAsync(VNPayFullRefundRequest request,
        CancellationToken ct = default);
    Task<VNPayRefundResult> QueryAsync(VNPayFullRefundRequest request,
        string queryRequestId, DateTimeOffset queryCreatedAt, CancellationToken ct = default);
}
