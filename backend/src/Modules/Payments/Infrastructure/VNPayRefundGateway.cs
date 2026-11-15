using System.Globalization;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Refunds;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>
/// VNPAY 2.1.0 refund/querydr transport, not a refund workflow or a disbursement API.
/// No automatic retries: transport errors are ambiguous money movement, not rejection.
/// </summary>
public sealed class VNPayRefundGateway(HttpClient client, IOptions<VNPayOptions> paymentOptions,
    IOptions<VNPayRefundOptions> refundOptions) : IVNPayRefundGateway
{
    private const int MaxResponseBytes = 64 * 1024;
    private static readonly string[] RefundHashFields =
    [
        "vnp_RequestId", "vnp_Version", "vnp_Command", "vnp_TmnCode", "vnp_TransactionType",
        "vnp_TxnRef", "vnp_Amount", "vnp_TransactionNo", "vnp_TransactionDate", "vnp_CreateBy",
        "vnp_CreateDate", "vnp_IpAddr", "vnp_OrderInfo"
    ];
    private static readonly string[] QueryHashFields =
    [
        "vnp_RequestId", "vnp_Version", "vnp_Command", "vnp_TmnCode", "vnp_TxnRef",
        "vnp_TransactionDate", "vnp_CreateDate", "vnp_IpAddr", "vnp_OrderInfo"
    ];
    private static readonly string[] ResponseHashFields =
    [
        "vnp_ResponseId", "vnp_Command", "vnp_ResponseCode", "vnp_Message",
        "vnp_TmnCode", "vnp_TxnRef", "vnp_Amount", "vnp_BankCode", "vnp_PayDate",
        "vnp_TransactionNo", "vnp_TransactionType", "vnp_TransactionStatus", "vnp_OrderInfo"
    ];

    public Task<VNPayRefundResult> SubmitAsync(VNPayFullRefundRequest request,
        CancellationToken ct = default)
    {
        var body = new Dictionary<string, string>
        {
            ["vnp_RequestId"] = request.RequestId,
            ["vnp_Version"] = "2.1.0",
            ["vnp_Command"] = "refund",
            ["vnp_TmnCode"] = request.MerchantCode,
            ["vnp_TransactionType"] = "02",
            ["vnp_TxnRef"] = request.OrderReference,
            ["vnp_Amount"] = checked(request.Amount * 100).ToString(CultureInfo.InvariantCulture),
            ["vnp_TransactionNo"] = request.OriginalTransactionId,
            ["vnp_TransactionDate"] = request.OriginalCreateDate,
            ["vnp_CreateBy"] = "SYSTEM",
            ["vnp_CreateDate"] = request.CreateDate,
            ["vnp_IpAddr"] = request.ServerIpAddress,
            ["vnp_OrderInfo"] = request.OrderInfo
        };
        // Explicit provider order, independent of JSON/dictionary enumeration order.
        var hashData = string.Join('|', RefundHashFields.Select(key => body[key]));
        return SendAsync(request, body, hashData, "refund", ct);
    }

    public Task<VNPayRefundResult> QueryAsync(VNPayFullRefundRequest request,
        string queryRequestId, DateTimeOffset queryCreatedAt, CancellationToken ct = default)
    {
        if (!VNPayFullRefundRequest.IsAlphaNumeric(queryRequestId, 1, 32) ||
            queryRequestId == request.RequestId ||
            string.CompareOrdinal(VNPayFullRefundRequest.FormatVietnamDate(queryCreatedAt), request.CreateDate) < 0)
            throw new ArgumentException("Use a new query ID and a date at or after the refund request.");
        var body = new Dictionary<string, string>
        {
            ["vnp_RequestId"] = queryRequestId,
            ["vnp_Version"] = "2.1.0",
            ["vnp_Command"] = "querydr",
            ["vnp_TmnCode"] = request.MerchantCode,
            ["vnp_TxnRef"] = request.OrderReference,
            ["vnp_TransactionDate"] = request.OriginalCreateDate,
            ["vnp_CreateDate"] = VNPayFullRefundRequest.FormatVietnamDate(queryCreatedAt),
            ["vnp_IpAddr"] = request.ServerIpAddress,
            ["vnp_OrderInfo"] = request.OrderInfo
        };
        return SendAsync(request, body, string.Join('|', QueryHashFields.Select(key => body[key])), "querydr", ct);
    }

    private async Task<VNPayRefundResult> SendAsync(VNPayFullRefundRequest snapshot,
        Dictionary<string, string> body, string hashData, string command, CancellationToken ct)
    {
        var options = refundOptions.Value;
        var credentials = paymentOptions.Value;
        if (!options.Enabled)
            throw new InvalidOperationException("VNPAY refund transport is disabled.");
        if (!IsValidEndpoint(options.ApiUrl) || credentials.Version != "2.1.0" ||
            credentials.TmnCode != snapshot.MerchantCode || string.IsNullOrWhiteSpace(credentials.HashSecret))
            throw new InvalidOperationException("VNPAY refund configuration does not match the persisted request.");
        body["vnp_SecureHash"] = Hash(hashData, credentials.HashSecret);

        try
        {
            using var outgoing = new HttpRequestMessage(HttpMethod.Post, options.ApiUrl)
            {
                Content = JsonContent.Create(body)
            };
            using var response = await client.SendAsync(outgoing, HttpCompletionOption.ResponseHeadersRead, ct);
            // HTTP status alone never proves whether VNPAY processed the refund.
            if (!response.IsSuccessStatusCode)
                return Unknown($"HTTP_{(int)response.StatusCode}");
            if (response.Content.Headers.ContentLength > MaxResponseBytes)
                return Unknown("RESPONSE_TOO_LARGE");
            await using var stream = await response.Content.ReadAsStreamAsync(ct);
            using var buffer = new MemoryStream();
            var chunk = new byte[4096];
            while (true)
            {
                var count = await stream.ReadAsync(chunk, ct);
                if (count == 0) break;
                if (buffer.Length + count > MaxResponseBytes) return Unknown("RESPONSE_TOO_LARGE");
                buffer.Write(chunk, 0, count);
            }
            return Interpret(snapshot, command, Encoding.UTF8.GetString(buffer.ToArray()), credentials.HashSecret);
        }
        catch (Exception ex) when (ex is HttpRequestException or IOException or OperationCanceledException)
        {
            // Even cancellation can arrive AFTER the provider accepted the request.
            // Do not leak connection details/credentials through exception messages.
            return Unknown("TRANSPORT_UNKNOWN");
        }
    }

    private static VNPayRefundResult Interpret(VNPayFullRefundRequest request,
        string command, string raw, string secret)
    {
        Dictionary<string, string> fields = new(StringComparer.Ordinal);
        try
        {
            using var document = JsonDocument.Parse(raw);
            if (document.RootElement.ValueKind != JsonValueKind.Object) return Unknown("INVALID_RESPONSE", raw);
            foreach (var property in document.RootElement.EnumerateObject())
            {
                if (property.Value.ValueKind is not (JsonValueKind.String or JsonValueKind.Number or JsonValueKind.Null) ||
                    !fields.TryAdd(property.Name, property.Value.ValueKind == JsonValueKind.Null
                        ? string.Empty : property.Value.ToString()))
                    return Unknown("INVALID_RESPONSE", raw);
            }
        }
        catch (JsonException)
        {
            return Unknown("INVALID_RESPONSE", raw);
        }

        string Get(string key) => fields.GetValueOrDefault(key, string.Empty);
        var hashFields = command == "querydr"
            ? ResponseHashFields.Concat(["vnp_PromotionCode", "vnp_PromotionAmount"])
            : ResponseHashFields;
        if (!VerifyHash(string.Join('|', hashFields.Select(Get)), Get("vnp_SecureHash"), secret))
            return Unknown("INVALID_SIGNATURE", raw);
        // querydr can return a successful ORIGINAL PAYMENT. It is NOT refund evidence.
        if (Get("vnp_Command") != command || Get("vnp_TmnCode") != request.MerchantCode ||
            Get("vnp_TxnRef") != request.OrderReference || Get("vnp_TransactionType") != "02" ||
            !VNPayFullRefundRequest.IsNumeric(Get("vnp_Amount"), 1, 12) ||
            !long.TryParse(Get("vnp_Amount"), NumberStyles.None, CultureInfo.InvariantCulture, out var amount) ||
            amount != checked(request.Amount * 100) ||
            !VNPayFullRefundRequest.IsAlphaNumeric(Get("vnp_ResponseId"), 1, 32))
            return Unknown("REFERENCE_MISMATCH", raw);

        var code = Get("vnp_ResponseCode");
        var status = Get("vnp_TransactionStatus");
        var state = (code, status) switch
        {
            ("00", "00") => VNPayRefundState.Confirmed,
            ("00", "01" or "05" or "06") => VNPayRefundState.Processing,
            ("94", _) => VNPayRefundState.Processing,
            ("00", "02" or "09") => VNPayRefundState.Rejected,
            _ => VNPayRefundState.Unknown
        };
        if (state == VNPayRefundState.Confirmed &&
            (!VNPayFullRefundRequest.IsNumeric(Get("vnp_TransactionNo"), 1, 15) ||
             Get("vnp_TransactionNo") == request.OriginalTransactionId ||
             !VNPayFullRefundRequest.IsDate(Get("vnp_PayDate")) ||
             string.CompareOrdinal(Get("vnp_PayDate"), request.CreateDate) < 0))
            return Unknown("MISSING_REFUND_EVIDENCE", raw);
        return new VNPayRefundResult(state, code, Get("vnp_ResponseId"),
            Get("vnp_TransactionNo"), status, raw);
    }

    internal static bool IsValidEndpoint(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps &&
        string.IsNullOrEmpty(uri.UserInfo) && string.IsNullOrEmpty(uri.Fragment) && string.IsNullOrEmpty(uri.Query);

    private static string Hash(string value, string secret) =>
        Convert.ToHexString(HMACSHA512.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(value)));

    private static bool VerifyHash(string value, string received, string secret)
    {
        if (received.Length != 128) return false;
        try
        {
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(Hash(value, secret)), Convert.FromHexString(received));
        }
        catch (FormatException) { return false; }
    }

    private static VNPayRefundResult Unknown(string code, string? raw = null) =>
        new(VNPayRefundState.Unknown, code, RawPayload: raw);
}
