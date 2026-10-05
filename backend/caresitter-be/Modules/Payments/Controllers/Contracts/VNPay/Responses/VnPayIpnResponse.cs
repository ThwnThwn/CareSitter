using System.Text.Json.Serialization;

namespace CareSitter.Modules.Payments.Application.VNPay.Dtos.Responses;

internal sealed record VnPayIpnResponse(
    [property: JsonPropertyName("RspCode")] string RspCode,
    [property: JsonPropertyName("Message")] string Message);
