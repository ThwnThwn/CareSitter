using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class VNPayRefundGatewayTests
{
    private const string Secret = "local-test-secret-not-a-merchant-key";
    private static readonly DateTimeOffset RequestTime = new(2026, 10, 4, 3, 12, 13, TimeSpan.Zero);
    private static readonly string[] SignedFields =
    [
        "vnp_ResponseId", "vnp_Command", "vnp_ResponseCode", "vnp_Message", "vnp_TmnCode",
        "vnp_TxnRef", "vnp_Amount", "vnp_BankCode", "vnp_PayDate", "vnp_TransactionNo",
        "vnp_TransactionType", "vnp_TransactionStatus", "vnp_OrderInfo"
    ];

    [Fact]
    public async Task Submit_sends_full_actual_paid_amount_and_exact_pipe_signature()
    {
        var handler = new FakeHandler(Signed(Response()));
        var result = await Gateway(handler).SubmitAsync(Request());
        var body = JsonSerializer.Deserialize<Dictionary<string, string>>(Assert.Single(handler.Bodies))!;
        Assert.Equal("02", body["vnp_TransactionType"]);
        Assert.Equal("52000000", body["vnp_Amount"]);
        Assert.Equal("20260930100000", body["vnp_TransactionDate"]);
        Assert.Equal("20261004101213", body["vnp_CreateDate"]);
        Assert.Equal("refundid01", body["vnp_RequestId"]);
        Assert.Equal("SYSTEM", body["vnp_CreateBy"]);
        Assert.Equal(Hash("refundid01|2.1.0|refund|TEST0001|02|CSorder01|52000000|123456|" +
            "20260930100000|SYSTEM|20261004101213|203.0.113.10|CareSitter full refund refundid01"),
            body["vnp_SecureHash"]);
        Assert.Equal(VNPayRefundState.Confirmed, result.State);
        Assert.Equal("654321", result.ProviderRefundId);
    }

    [Fact]
    public async Task Snapshot_does_not_generate_a_new_id_or_timestamp_on_repeat_submission()
    {
        // This tests wire stability, not permission to retry money movement.
        var handler = new FakeHandler(Signed(Response()));
        var gateway = Gateway(handler);
        var request = Request();
        await gateway.SubmitAsync(request);
        await gateway.SubmitAsync(request);
        Assert.Equal(2, handler.Bodies.Count);
        Assert.Equal(handler.Bodies[0], handler.Bodies[1]);
    }

    [Theory]
    [InlineData("00", "00", VNPayRefundState.Confirmed)]
    [InlineData("00", "01", VNPayRefundState.Processing)]
    [InlineData("00", "05", VNPayRefundState.Processing)]
    [InlineData("00", "06", VNPayRefundState.Processing)]
    [InlineData("94", "05", VNPayRefundState.Processing)]
    [InlineData("00", "02", VNPayRefundState.Rejected)]
    [InlineData("00", "09", VNPayRefundState.Rejected)]
    [InlineData("00", "04", VNPayRefundState.Unknown)]
    [InlineData("00", "07", VNPayRefundState.Unknown)]
    [InlineData("00", "", VNPayRefundState.Unknown)]
    [InlineData("98", "00", VNPayRefundState.Unknown)]
    [InlineData("99", "00", VNPayRefundState.Unknown)]
    [InlineData("95", "00", VNPayRefundState.Unknown)]
    public async Task Only_verified_final_refund_evidence_is_confirmed(
        string code, string status, VNPayRefundState expected)
    {
        var fields = Response();
        fields["vnp_ResponseCode"] = code;
        fields["vnp_TransactionStatus"] = status;
        var result = await Gateway(new FakeHandler(Signed(fields))).SubmitAsync(Request());
        Assert.Equal(expected, result.State);
    }

    [Theory]
    [InlineData("vnp_Command", "pay")]
    [InlineData("vnp_TmnCode", "OTHER001")]
    [InlineData("vnp_TxnRef", "wrongOrder")]
    [InlineData("vnp_Amount", "52000001")]
    [InlineData("vnp_Amount", "-52000000")]
    [InlineData("vnp_Amount", "5.2E7")]
    [InlineData("vnp_TransactionType", "01")]
    [InlineData("vnp_TransactionType", "03")]
    [InlineData("vnp_ResponseId", "")]
    public async Task Even_signed_response_with_wrong_binding_is_unknown(string key, string value)
    {
        var fields = Response();
        fields[key] = value;
        var result = await Gateway(new FakeHandler(Signed(fields))).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("REFERENCE_MISMATCH", result.Code);
    }

    [Theory]
    [InlineData("vnp_TransactionNo", "")]
    [InlineData("vnp_TransactionNo", "123456")]
    [InlineData("vnp_PayDate", "")]
    [InlineData("vnp_PayDate", "20260230101300")]
    [InlineData("vnp_PayDate", "20260930101300")]
    public async Task Successful_payment_or_old_refund_is_not_current_refund_evidence(string key, string value)
    {
        var fields = Response();
        fields[key] = value;
        var result = await Gateway(new FakeHandler(Signed(fields))).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("MISSING_REFUND_EVIDENCE", result.Code);
    }

    [Fact]
    public async Task Tampered_payload_is_unknown()
    {
        var signed = Signed(Response()).Replace("52000000", "52000001");
        var result = await Gateway(new FakeHandler(signed)).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("INVALID_SIGNATURE", result.Code);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-hex")]
    [InlineData("0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000z")]
    public async Task Missing_or_malformed_signature_is_unknown(string hash)
    {
        var fields = Response();
        fields["vnp_SecureHash"] = hash;
        var result = await Gateway(new FakeHandler(JsonSerializer.Serialize(fields))).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("INVALID_SIGNATURE", result.Code);
    }

    [Fact]
    public async Task Lowercase_valid_signature_is_accepted()
    {
        var fields = Response();
        var body = JsonSerializer.Deserialize<Dictionary<string, string>>(Signed(fields))!;
        body["vnp_SecureHash"] = body["vnp_SecureHash"].ToLowerInvariant();
        Assert.Equal(VNPayRefundState.Confirmed,
            (await Gateway(new FakeHandler(JsonSerializer.Serialize(body))).SubmitAsync(Request())).State);
    }

    [Theory]
    [InlineData("not-json")]
    [InlineData("[]")]
    [InlineData("{\"vnp_Amount\":{},\"vnp_SecureHash\":\"\"}")]
    [InlineData("{\"vnp_Amount\":\"52000000\",\"vnp_Amount\":\"1\"}")]
    public async Task Malformed_or_duplicate_json_fields_are_unknown(string payload)
    {
        var result = await Gateway(new FakeHandler(payload)).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("INVALID_RESPONSE", result.Code);
    }

    [Theory]
    [InlineData(HttpStatusCode.InternalServerError)]
    [InlineData(HttpStatusCode.TemporaryRedirect)]
    [InlineData(HttpStatusCode.TooManyRequests)]
    public async Task Http_error_is_ambiguous_even_with_success_payload(HttpStatusCode status)
    {
        var handler = new FakeHandler(Signed(Response()), status);
        var result = await Gateway(handler).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal($"HTTP_{(int)status}", result.Code);
        Assert.Single(handler.Bodies);
    }

    [Theory]
    [InlineData("timeout")]
    [InlineData("disconnect")]
    [InlineData("read-error")]
    public async Task Transport_failure_after_send_is_unknown_and_never_retried(string failure)
    {
        var handler = new FakeHandler("", failure: failure);
        var result = await Gateway(handler).SubmitAsync(Request());
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("TRANSPORT_UNKNOWN", result.Code);
        Assert.Single(handler.Bodies);
    }

    [Fact]
    public async Task Oversized_response_is_unknown()
    {
        var result = await Gateway(new FakeHandler(new string('x', 65537))).SubmitAsync(Request());
        Assert.Equal("RESPONSE_TOO_LARGE", result.Code);
        Assert.Equal(VNPayRefundState.Unknown, result.State);
    }

    [Fact]
    public async Task Disabled_by_default_and_no_request_sent()
    {
        var handler = new FakeHandler(Signed(Response()));
        var gateway = Gateway(handler, refundOptions: new VNPayRefundOptions());
        await Assert.ThrowsAsync<InvalidOperationException>(() => gateway.SubmitAsync(Request()));
        Assert.Empty(handler.Bodies);
    }

    [Theory]
    [InlineData("http://sandbox.vnpayment.vn/merchant_webapi/api/transaction")]
    [InlineData("https://user:secret@example.test/refund")]
    [InlineData("https://example.test/refund?secret=x")]
    [InlineData("https://example.test/refund#fragment")]
    public async Task Invalid_endpoint_is_rejected_before_send(string endpoint)
    {
        var handler = new FakeHandler("");
        await Assert.ThrowsAsync<InvalidOperationException>(() => Gateway(handler,
            refundOptions: new VNPayRefundOptions { Enabled = true, ApiUrl = endpoint }).SubmitAsync(Request()));
        Assert.Empty(handler.Bodies);
    }

    [Theory]
    [InlineData("OTHER001", "2.1.0", Secret)]
    [InlineData("TEST0001", "2.0.0", Secret)]
    [InlineData("TEST0001", "2.1.0", "")]
    public async Task Misconfigured_merchant_version_or_key_is_rejected_before_send(
        string merchant, string version, string secret)
    {
        var handler = new FakeHandler("");
        await Assert.ThrowsAsync<InvalidOperationException>(() => Gateway(handler,
            new VNPayOptions { TmnCode = merchant, Version = version, HashSecret = secret }).SubmitAsync(Request()));
        Assert.Empty(handler.Bodies);
    }

    [Fact]
    public async Task Query_signs_its_own_request_and_verifies_query_specific_response_hash()
    {
        var fields = Response("querydr");
        fields["vnp_PromotionCode"] = "PROMO";
        fields["vnp_PromotionAmount"] = "10000";
        var handler = new FakeHandler(Signed(fields, query: true));
        var result = await Gateway(handler).QueryAsync(Request(), "query01", RequestTime.AddMinutes(1));
        var body = JsonSerializer.Deserialize<Dictionary<string, string>>(Assert.Single(handler.Bodies))!;
        Assert.Equal("querydr", body["vnp_Command"]);
        Assert.Equal(Hash("query01|2.1.0|querydr|TEST0001|CSorder01|20260930100000|" +
            "20261004101313|203.0.113.10|CareSitter full refund refundid01"), body["vnp_SecureHash"]);
        Assert.Equal(VNPayRefundState.Confirmed, result.State);
    }

    [Fact]
    public async Task Query_of_successful_original_payment_does_not_confirm_refund()
    {
        var fields = Response("querydr");
        fields["vnp_TransactionType"] = "01";
        fields["vnp_TransactionNo"] = "123456";
        var result = await Gateway(new FakeHandler(Signed(fields, query: true)))
            .QueryAsync(Request(), "query01", RequestTime.AddMinutes(1));
        Assert.Equal(VNPayRefundState.Unknown, result.State);
        Assert.Equal("REFERENCE_MISMATCH", result.Code);
    }

    [Fact]
    public async Task Query_cannot_use_refund_request_id_or_older_timestamp()
    {
        var handler = new FakeHandler("");
        var gateway = Gateway(handler);
        await Assert.ThrowsAsync<ArgumentException>(() => gateway.QueryAsync(Request(), "refundid01", RequestTime));
        await Assert.ThrowsAsync<ArgumentException>(() => gateway.QueryAsync(Request(), "query01", RequestTime.AddSeconds(-1)));
        Assert.Empty(handler.Bodies);
    }

    [Theory]
    [InlineData("CREATED", "VNPAY", "VND", 520000)]
    [InlineData("PENDING", "VNPAY", "VND", 520000)]
    [InlineData("SUCCEEDED", "MOMO", "VND", 520000)]
    [InlineData("SUCCEEDED", "VNPAY", "USD", 520000)]
    [InlineData("SUCCEEDED", "VNPAY", "VND", 0)]
    [InlineData("SUCCEEDED", "VNPAY", "VND", 10000000000)]
    public void Request_rejects_unpaid_unsupported_or_out_of_range_payment(
        string status, string provider, string currency, long amount)
    {
        Assert.True(VNPayFullRefundRequest.Create(Intent(status, provider, currency, amount),
            "refundid01", "TEST0001", "20260930100000", RequestTime, "203.0.113.10").IsFailure);
    }

    [Theory]
    [InlineData("bad|id", "TEST0001", "20260930100000", "203.0.113.10")]
    [InlineData("refundid01", "BAD", "20260930100000", "203.0.113.10")]
    [InlineData("refundid01", "TEST0001", "20260230000000", "203.0.113.10")]
    [InlineData("refundid01", "TEST0001", "20261005100000", "203.0.113.10")]
    [InlineData("refundid01", "TEST0001", "", "203.0.113.10")]
    [InlineData("refundid01", "TEST0001", "20260930100000", "server.test")]
    public void Request_rejects_invalid_wire_fields(string id, string merchant, string date, string ip)
    {
        Assert.True(VNPayFullRefundRequest.Create(Intent(), id, merchant, date, RequestTime, ip).IsFailure);
    }

    [Fact]
    public void Request_requires_original_provider_reference_and_transaction()
    {
        var intent = PaymentIntent.Create(Guid.NewGuid(), Guid.NewGuid(), "VNPAY", 520000, "key").Value;
        Assert.True(intent.MarkSucceeded().IsSuccess);
        Assert.True(VNPayFullRefundRequest.Create(intent, "refundid01", "TEST0001",
            "20260930100000", RequestTime, "203.0.113.10").IsFailure);
    }

    private static VNPayFullRefundRequest Request() => VNPayFullRefundRequest.Create(Intent(),
        "refundid01", "TEST0001", "20260930100000", RequestTime, "203.0.113.10").Value;

    private static PaymentIntent Intent(string status = "SUCCEEDED", string provider = "VNPAY",
        string currency = "VND", long amount = 520000)
    {
        var intent = PaymentIntent.Create(Guid.NewGuid(), Guid.NewGuid(), provider,
            amount, Guid.NewGuid().ToString("N"), currency,
            new DateTimeOffset(2026, 9, 30, 3, 0, 0, TimeSpan.Zero)).Value;
        Assert.True(intent.SetProviderOrderRef("CSorder01").IsSuccess);
        if (status == "PENDING") Assert.True(intent.MarkPending().IsSuccess);
        if (status == "SUCCEEDED") Assert.True(intent.MarkSucceeded("123456").IsSuccess);
        return intent;
    }

    [Fact]
    public void Request_cannot_guess_or_replace_the_original_payment_date()
    {
        var intent = Intent();
        Assert.True(VNPayFullRefundRequest.Create(intent, "refundid01", "TEST0001",
            "20260930100001", RequestTime, "203.0.113.10").IsFailure);
        typeof(PaymentIntent).GetProperty(nameof(PaymentIntent.ProviderCreateDate))!.SetValue(intent, null);
        Assert.True(VNPayFullRefundRequest.Create(intent, "refundid01", "TEST0001",
            "20260930100000", RequestTime, "203.0.113.10").IsFailure);
    }

    private static VNPayRefundGateway Gateway(FakeHandler handler, VNPayOptions? paymentOptions = null,
        VNPayRefundOptions? refundOptions = null) => new(new HttpClient(handler),
        Options.Create(paymentOptions ?? new VNPayOptions { TmnCode = "TEST0001", HashSecret = Secret }),
        Options.Create(refundOptions ?? new VNPayRefundOptions
        {
            Enabled = true, ApiUrl = "https://sandbox.vnpayment.vn/merchant_webapi/api/transaction"
        }));

    private static Dictionary<string, string> Response(string command = "refund") => new()
    {
        ["vnp_ResponseId"] = "providerresponse01", ["vnp_Command"] = command,
        ["vnp_ResponseCode"] = "00", ["vnp_Message"] = "provider-message",
        ["vnp_TmnCode"] = "TEST0001", ["vnp_TxnRef"] = "CSorder01", ["vnp_Amount"] = "52000000",
        ["vnp_BankCode"] = "NCB", ["vnp_PayDate"] = "20261004101300",
        ["vnp_TransactionNo"] = "654321", ["vnp_TransactionType"] = "02",
        ["vnp_TransactionStatus"] = "00", ["vnp_OrderInfo"] = "CareSitter full refund refundid01"
    };

    private static string Signed(Dictionary<string, string> fields, bool query = false)
    {
        var keys = query ? SignedFields.Concat(["vnp_PromotionCode", "vnp_PromotionAmount"]) : SignedFields;
        fields["vnp_SecureHash"] = Hash(string.Join('|', keys.Select(key => fields.GetValueOrDefault(key, ""))));
        return JsonSerializer.Serialize(fields);
    }

    private static string Hash(string value) => Convert.ToHexString(
        HMACSHA512.HashData(Encoding.UTF8.GetBytes(Secret), Encoding.UTF8.GetBytes(value)));

    private sealed class FakeHandler(string body, HttpStatusCode status = HttpStatusCode.OK,
        string? failure = null) : HttpMessageHandler
    {
        public List<string> Bodies { get; } = [];
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Bodies.Add(await request.Content!.ReadAsStringAsync(ct));
            if (failure == "timeout") throw new TaskCanceledException("timeout");
            if (failure == "disconnect") throw new HttpRequestException("disconnect");
            if (failure == "read-error") throw new IOException("connection reset");
            return new HttpResponseMessage(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        }
    }
}
