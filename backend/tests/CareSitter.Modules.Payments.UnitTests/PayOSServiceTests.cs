using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class PayOSServiceTests
{
    private const string Key = "1a54716c8f0efb2744fb28b6e38b25da7f67a925d98bc1c18bd8faaecadd7675";
    private static PayOSOptions Config(bool enabled = true) => new()
    {
        Enabled = enabled, ClientId = "test-client", ApiKey = "test-api", ChecksumKey = Key,
        ReturnUrl = "https://example.com/api/v1/payments/payos/return",
        CancelUrl = "https://example.com/api/v1/payments/payos/cancel"
    };

    [Fact]
    public void Signature_matches_official_payOS_fixture_and_rejects_tampering()
    {
        var data = JsonSerializer.SerializeToElement(new
        {
            orderCode = 123, amount = 3000, description = "VQRIO123", accountNumber = "12345678",
            reference = "TF230204212323", transactionDateTime = "2023-02-04 18:25:00",
            currency = "VND", paymentLinkId = "124c33293c43417ab7879e14c8d9eb18", code = "00",
            desc = "Thành công", counterAccountBankId = "", counterAccountBankName = "",
            counterAccountName = "", counterAccountNumber = "", virtualAccountName = "", virtualAccountNumber = ""
        });
        const string signature = "412e915d2871504ed31be63c8f62a149a4410d34c4c42affc9006ef9917eaa03";
        Assert.True(PayOSSignature.Verify(data, signature, Key));
        Assert.False(PayOSSignature.Verify(data, signature, "wrong-checksum-key"));
        Assert.False(PayOSSignature.Verify(data, "00", Key));
        var changed = JsonDocument.Parse(data.GetRawText().Replace("3000", "3001")).RootElement;
        Assert.False(PayOSSignature.Verify(changed, signature, Key));
    }

    [Fact]
    public void Webhook_rejects_duplicate_keys_and_invalid_signature_even_if_disabled()
    {
        var service = Service(_ => throw new InvalidOperationException(), enabled: false);
        var data = JsonSerializer.SerializeToElement(new { orderCode = 123, amount = 3000 });
        var signature = PayOSSignature.Sign(PayOSSignature.Canonicalize(data), Key);
        Assert.True(service.VerifyWebhook(JsonSerializer.SerializeToElement(new { data, signature })));
        Assert.False(service.VerifyWebhook(JsonDocument.Parse(
            $$"""{"data":{"orderCode":123,"amount":3000,"amount":1},"signature":"{{signature}}"}""").RootElement));
        Assert.False(service.VerifyWebhook(JsonSerializer.SerializeToElement(new { data, signature = "forged" })));
    }

    [Fact]
    public async Task Create_sends_server_amount_signed_request_credentials_and_deadline()
    {
        var intent = Intent();
        var config = Config();
        var calls = 0;
        var service = Service(async request =>
        {
            calls++;
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal("api-merchant.payos.vn", request.RequestUri!.Host);
            Assert.Equal(config.ClientId, request.Headers.GetValues("x-client-id").Single());
            Assert.Equal(config.ApiKey, request.Headers.GetValues("x-api-key").Single());
            using var json = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
            var root = json.RootElement;
            Assert.Equal(intent.Amount, root.GetProperty("amount").GetInt64());
            Assert.Equal(123, root.GetProperty("orderCode").GetInt64());
            Assert.Equal(intent.ProviderExpiresAt!.Value.ToUnixTimeSeconds(), root.GetProperty("expiredAt").GetInt64());
            var description = root.GetProperty("description").GetString();
            Assert.Equal(9, description!.Length);
            var canonical = $"amount=100000&cancelUrl={config.CancelUrl}&description={description}&orderCode=123&returnUrl={config.ReturnUrl}";
            var expected = Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(Key), Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
            Assert.Equal(expected, root.GetProperty("signature").GetString());
            return Signed(new { orderCode = 123, amount = 100000, currency = "VND",
                paymentLinkId = "link123", checkoutUrl = "https://pay.payos.vn/web/link123", accountNumber = "12345678" });
        });
        var link = await service.CreateLinkAsync(intent);
        Assert.Equal(1, calls);
        Assert.Equal("link123", link.PaymentLinkId);
    }

    [Theory]
    [InlineData("PAID", 100000, 0, PaymentProviderState.Succeeded)]
    [InlineData("PAID", 90000, 10000, PaymentProviderState.Unknown)]
    [InlineData("PAID", 110000, 0, PaymentProviderState.Unknown)]
    [InlineData("PENDING", 0, 100000, PaymentProviderState.Processing)]
    [InlineData("PROCESSING", 3000, 97000, PaymentProviderState.Processing)]
    [InlineData("PENDING", 0, 0, PaymentProviderState.Unknown)]
    [InlineData("CANCELLED", 0, 100000, PaymentProviderState.Failed)]
    [InlineData("CANCELLED", 3000, 97000, PaymentProviderState.Unknown)]
    [InlineData("EXPIRED", 0, 100000, PaymentProviderState.NotFound)]
    public async Task Query_requires_consistent_signed_totals(string status, long paid, long remaining, PaymentProviderState expected)
    {
        var service = Service(_ => Task.FromResult(Signed(new { id = "link123", orderCode = 123,
            amount = 100000, amountPaid = paid, amountRemaining = remaining, status })), enabled: false);
        var result = await service.QueryAsync(Intent());
        Assert.Equal(expected, result.State);
    }

    [Theory]
    [InlineData(124, 100000, "VND", "link123")]
    [InlineData(123, 1, "VND", "link123")]
    [InlineData(123, 100000, "USD", "link123")]
    [InlineData(123, 100000, "VND", "another-link")]
    public async Task Query_rejects_wrong_order_amount_currency_or_link(long orderCode, long amount, string currency, string id)
    {
        var intent = Intent();
        intent.AttachPayOSLink("link123", "https://pay.payos.vn/web/link123");
        var service = Service(_ => Task.FromResult(Signed(new { id, orderCode, amount, currency,
            amountPaid = amount, amountRemaining = 0, status = "PAID" })));
        Assert.Equal(PaymentProviderState.Unknown, (await service.QueryAsync(intent)).State);
    }

    [Fact]
    public async Task Unsigned_paid_response_and_network_failure_cannot_finalize_payment()
    {
        var unsigned = Service(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        { Content = new StringContent("{\"code\":\"00\",\"data\":{\"status\":\"PAID\"}}") }));
        Assert.Equal(PaymentProviderState.Unknown, (await unsigned.QueryAsync(Intent())).State);
        var down = Service(_ => throw new HttpRequestException("test"));
        Assert.Equal(PaymentProviderState.Unknown, (await down.QueryAsync(Intent())).State);
    }

    [Theory]
    [InlineData("https://attacker.example/web/link123")]
    [InlineData("http://pay.payos.vn/web/link123")]
    [InlineData("https://user:pass@pay.payos.vn/web/link123")]
    public async Task Create_rejects_untrusted_checkout_URL(string url)
    {
        var service = Service(_ => Task.FromResult(Signed(new { orderCode = 123, amount = 100000,
            currency = "VND", paymentLinkId = "link123", checkoutUrl = url, accountNumber = "12345678" })));
        await Assert.ThrowsAsync<InvalidDataException>(() => service.CreateLinkAsync(Intent()));
    }

    [Fact]
    public async Task Disabled_gateway_does_not_issue_a_real_payment()
    {
        var service = Service(_ => throw new InvalidOperationException("Must not call HTTP"), enabled: false);
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.CreateLinkAsync(Intent()));
        Assert.True(PayOSOptions.IsValid(new PayOSOptions()));
        Assert.False(PayOSOptions.IsValid(new PayOSOptions { Enabled = true }));
        var config = Config(); config.ReturnUrl = "http://localhost/return";
        Assert.False(PayOSOptions.IsValid(config));
    }

    private static PaymentIntent Intent()
    {
        var intent = PaymentIntent.Create(Guid.NewGuid(), Guid.NewGuid(), "PAYOS", 100000, Guid.NewGuid().ToString()).Value;
        intent.SetProviderOrderRef("123");
        intent.ConfigurePayOS(DateTimeOffset.UtcNow.AddMinutes(30));
        intent.MarkPending();
        return intent;
    }

    private static HttpResponseMessage Signed(object value)
    {
        var data = JsonSerializer.SerializeToElement(value);
        var signature = PayOSSignature.Sign(PayOSSignature.Canonicalize(data), Key);
        return new(HttpStatusCode.OK) { Content = new StringContent(JsonSerializer.Serialize(new { code = "00", data, signature })) };
    }

    private static PayOSService Service(Func<HttpRequestMessage, Task<HttpResponseMessage>> send, bool enabled = true) =>
        new(new HttpClient(new Handler(send)), Options.Create(Config(enabled)));

    private sealed class Handler(Func<HttpRequestMessage, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request);
    }
}
