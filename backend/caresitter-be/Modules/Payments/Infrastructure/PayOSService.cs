using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSService(HttpClient client, IOptions<PayOSOptions> options) : IPayOSService
{
    private const string ApiBase = "https://api-merchant.payos.vn/v2/payment-requests";

    public async Task<PayOSPaymentLink> CreateLinkAsync(PaymentIntent intent, CancellationToken ct = default)
    {
        var config = RequireEnabled();
        var orderCode = ParseOrderCode(intent.ProviderOrderRef);
        var description = $"CS{intent.Id:N}"[..9];
        var signature = PayOSSignature.Sign(FormattableString.Invariant(
            $"amount={intent.Amount}&cancelUrl={config.CancelUrl}&description={description}&orderCode={orderCode}&returnUrl={config.ReturnUrl}"), config.ChecksumKey);
        using var request = Request(HttpMethod.Post, ApiBase, config);
        request.Content = JsonContent.Create(new
        {
            orderCode, amount = intent.Amount, description, cancelUrl = config.CancelUrl,
            returnUrl = config.ReturnUrl, expiredAt = intent.ProviderExpiresAt!.Value.ToUnixTimeSeconds(), signature
        });
        using var document = await SendAsync(request, ct);
        var data = document.RootElement.GetProperty("data");
        ValidateOrder(data, intent);
        if (data.GetProperty("currency").GetString() != "VND")
            throw new InvalidDataException("payOS currency mismatch.");
        var linkId = RequiredString(data, "paymentLinkId", 100);
        var checkoutUrl = RequiredString(data, "checkoutUrl", 2048);
        if (!Uri.TryCreate(checkoutUrl, UriKind.Absolute, out var uri) || uri.Scheme != "https" ||
            uri.Host != "pay.payos.vn" || !uri.IsDefaultPort || !string.IsNullOrEmpty(uri.UserInfo))
            throw new InvalidDataException("Invalid payOS checkout URL.");
        return new(orderCode, intent.Amount, linkId, checkoutUrl,
            RequiredString(data, "accountNumber", 100), document.RootElement.GetRawText());
    }

    public async Task<PaymentProviderQuery> QueryAsync(PaymentIntent intent, CancellationToken ct = default)
    {
        try
        {
            var config = RequireCredentials();
            var orderCode = ParseOrderCode(intent.ProviderOrderRef);
            using var request = Request(HttpMethod.Get, $"{ApiBase}/{orderCode.ToString(CultureInfo.InvariantCulture)}", config);
            using var document = await SendAsync(request, ct);
            var data = document.RootElement.GetProperty("data");
            ValidateOrder(data, intent);
            var id = RequiredString(data, "id", 100);
            if (intent.ProviderLinkId is not null && intent.ProviderLinkId != id)
                throw new InvalidDataException("payOS link mismatch.");
            var paid = data.GetProperty("amountPaid").GetInt64();
            var remaining = data.GetProperty("amountRemaining").GetInt64();
            var status = RequiredString(data, "status", 30);
            var state = status switch
            {
                "PAID" when paid == intent.Amount && remaining == 0 => PaymentProviderState.Succeeded,
                "PENDING" or "PROCESSING" when paid >= 0 && paid <= intent.Amount &&
                    remaining == intent.Amount - paid => PaymentProviderState.Processing,
                "CANCELLED" when paid == 0 => PaymentProviderState.Failed,
                "EXPIRED" when paid == 0 => PaymentProviderState.NotFound,
                _ => PaymentProviderState.Unknown
            };
            return new(state, id, document.RootElement.GetRawText(),
                state == PaymentProviderState.Unknown ? "Số tiền hoặc trạng thái payOS cần đối soát." : null);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or JsonException or
            InvalidDataException or InvalidOperationException or FormatException or OverflowException or KeyNotFoundException)
        {
            if (ct.IsCancellationRequested) throw;
            return new(PaymentProviderState.Unknown, null, "{}", "Chưa xác minh được giao dịch payOS.");
        }
    }

    public bool VerifyWebhook(JsonElement payload)
    {
        if (!options.Value.HasCredentials || payload.ValueKind != JsonValueKind.Object) return false;
        try
        {
            PayOSSignature.RejectDuplicateKeys(payload);
            return payload.TryGetProperty("data", out var data) &&
                payload.TryGetProperty("signature", out var signature) && signature.ValueKind == JsonValueKind.String &&
                PayOSSignature.Verify(data, signature.GetString(), options.Value.ChecksumKey);
        }
        catch (JsonException) { return false; }
    }

    private PayOSOptions RequireEnabled() => options.Value.Enabled && PayOSOptions.IsValid(options.Value)
        ? options.Value : throw new InvalidOperationException("payOS is unavailable.");

    private PayOSOptions RequireCredentials() => options.Value.HasCredentials
        ? options.Value : throw new InvalidOperationException("payOS is unavailable.");

    private static HttpRequestMessage Request(HttpMethod method, string url, PayOSOptions config)
    {
        var request = new HttpRequestMessage(method, url);
        request.Headers.Add("x-client-id", config.ClientId);
        request.Headers.Add("x-api-key", config.ApiKey);
        return request;
    }

    private async Task<JsonDocument> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(10));
        ct = timeout.Token;
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        response.EnsureSuccessStatusCode();
        // Không ghi body/khóa API vào log, không theo redirect và không tự retry POST.
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var memory = new MemoryStream();
        var buffer = new byte[8192];
        int count;
        while ((count = await stream.ReadAsync(buffer, ct)) > 0)
        {
            if (memory.Length + count > 256 * 1024) throw new InvalidDataException("payOS response too large.");
            memory.Write(buffer, 0, count);
        }
        var document = JsonDocument.Parse(memory.ToArray());
        try
        {
            var root = document.RootElement;
            PayOSSignature.RejectDuplicateKeys(root);
            if (root.GetProperty("code").GetString() != "00" ||
                !root.TryGetProperty("data", out var data) ||
                !root.TryGetProperty("signature", out var signature) ||
                !PayOSSignature.Verify(data, signature.GetString(), options.Value.ChecksumKey))
                throw new InvalidDataException("Unverified payOS response.");
            return document;
        }
        catch { document.Dispose(); throw; }
    }

    private static void ValidateOrder(JsonElement data, PaymentIntent intent)
    {
        if (data.GetProperty("orderCode").GetInt64() != ParseOrderCode(intent.ProviderOrderRef) ||
            data.GetProperty("amount").GetInt64() != intent.Amount || intent.Currency != "VND" ||
            (data.TryGetProperty("currency", out var currency) && currency.GetString() != "VND"))
            throw new InvalidDataException("payOS order/amount mismatch.");
    }

    internal static long ParseOrderCode(string? value) =>
        long.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var result) &&
        result is > 0 and <= 9_007_199_254_740_991 ? result : throw new FormatException("Invalid payOS order code.");

    internal static string RequiredString(JsonElement data, string key, int maxLength)
    {
        var value = data.GetProperty(key).GetString();
        return !string.IsNullOrWhiteSpace(value) && value.Length <= maxLength
            ? value : throw new InvalidDataException($"Invalid payOS {key}.");
    }
}
