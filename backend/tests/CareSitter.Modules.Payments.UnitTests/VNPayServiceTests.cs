using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class VNPayServiceTests
{
    [Fact]
    public void BuildPaymentUrl_UsesVietnamTimeAndConfiguredExpiry()
    {
        var intent = PaymentIntent.Create(
            Guid.NewGuid(), Guid.NewGuid(), "VNPAY", 520_000, "test-key").Value;
        Assert.True(intent.SetProviderOrderRef($"CS{intent.Id:N}"[..34]).IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);

        var options = new VNPayOptions
        {
            TmnCode = "TEST",
            HashSecret = "test-secret",
            PaymentUrl = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
            ReturnUrl = "https://example.test/api/v1/payments/vnpay/return",
            PaymentTimeoutMinutes = 15
        };

        var before = VietnamNow();
        var url = new VNPayService(new HttpClient()).BuildPaymentUrl(intent, options);
        var after = VietnamNow();
        var query = ParseQuery(new Uri(url).Query);
        var createDate = DateTime.ParseExact(
            query["vnp_CreateDate"], "yyyyMMddHHmmss", CultureInfo.InvariantCulture);
        var expireDate = DateTime.ParseExact(
            query["vnp_ExpireDate"], "yyyyMMddHHmmss", CultureInfo.InvariantCulture);

        Assert.InRange(createDate, before.AddSeconds(-1), after.AddSeconds(1));
        Assert.Equal(TimeSpan.FromMinutes(15), expireDate - createDate);
    }

    [Fact]
    public void BuildPaymentUrl_UsesBookingCustomerNameForOrderInfo()
    {
        var intent = CreatePendingIntent();
        var url = new VNPayService(new HttpClient()).BuildPaymentUrl(
            intent, QueryOptions(), "Nguyen Van Hung");

        var query = ParseQuery(new Uri(url).Query);

        Assert.Equal("Thanh toán đơn hàng của khách hàng Nguyen Van Hung", query["vnp_OrderInfo"]);
        Assert.DoesNotContain(intent.ProviderOrderRef!, query["vnp_OrderInfo"]);
    }

    [Theory]
    [InlineData("00", "00", VNPayQueryState.Succeeded)]
    [InlineData("00", "01", VNPayQueryState.Processing)]
    [InlineData("00", "02", VNPayQueryState.Failed)]
    [InlineData("91", null, VNPayQueryState.NotFound)]
    [InlineData("97", null, VNPayQueryState.Unknown)]
    public async Task QueryTransaction_MapsProviderStateAndSignsRequest(
        string responseCode, string? transactionStatus, VNPayQueryState expected)
    {
        var response = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["vnp_ResponseCode"] = responseCode,
            ["vnp_TransactionStatus"] = transactionStatus,
            ["vnp_TransactionNo"] = "123456",
            ["vnp_Message"] = "provider-message"
        });
        var handler = new CapturingHandler(response);
        var service = new VNPayService(new HttpClient(handler));
        var intent = CreatePendingIntent();
        var options = QueryOptions();

        var result = await service.QueryTransactionAsync(intent, options);

        Assert.Equal(expected, result.State);
        Assert.Equal("provider-message", result.Message);
        Assert.NotNull(handler.RequestBody);
        var body = JsonSerializer.Deserialize<Dictionary<string, string>>(handler.RequestBody!)!;
        var hashData = string.Join('|', body["vnp_RequestId"], body["vnp_Version"],
            body["vnp_Command"], body["vnp_TmnCode"], body["vnp_TxnRef"],
            body["vnp_TransactionDate"], body["vnp_CreateDate"], body["vnp_IpAddr"],
            body["vnp_OrderInfo"]);
        Assert.Equal(ComputeHash(hashData, options.HashSecret), body["vnp_SecureHash"]);
    }

    [Fact]
    public async Task QueryTransaction_InvalidJson_ReturnsUnknownInsteadOfThrowing()
    {
        var service = new VNPayService(new HttpClient(new CapturingHandler("not-json")));

        var result = await service.QueryTransactionAsync(CreatePendingIntent(), QueryOptions());

        Assert.Equal(VNPayQueryState.Unknown, result.State);
        Assert.Equal("INVALID_RESPONSE", result.ResponseCode);
    }

    private static PaymentIntent CreatePendingIntent()
    {
        var intent = PaymentIntent.Create(
            Guid.NewGuid(), Guid.NewGuid(), "VNPAY", 520_000, Guid.NewGuid().ToString("N")).Value;
        Assert.True(intent.SetProviderOrderRef($"CS{intent.Id:N}"[..34]).IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        return intent;
    }

    private static VNPayOptions QueryOptions() => new()
    {
        TmnCode = "TEST",
        HashSecret = "test-secret",
        QueryUrl = "https://sandbox.vnpayment.vn/merchant_webapi/api/transaction"
    };

    private static string ComputeHash(string data, string secret)
    {
        using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(data)));
    }

    private static DateTime VietnamNow()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(
            OperatingSystem.IsWindows() ? "SE Asia Standard Time" : "Asia/Ho_Chi_Minh");
        return TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, zone).DateTime;
    }

    private static Dictionary<string, string> ParseQuery(string query) =>
        query.TrimStart('?')
            .Split('&', StringSplitOptions.RemoveEmptyEntries)
            .Select(part => part.Split('=', 2))
            .ToDictionary(
                part => Uri.UnescapeDataString(part[0].Replace('+', ' ')),
                part => Uri.UnescapeDataString(part[1].Replace('+', ' ')));

    private sealed class CapturingHandler(string responseBody) : HttpMessageHandler
    {
        public string? RequestBody { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestBody = await request.Content!.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
            };
        }
    }
}
