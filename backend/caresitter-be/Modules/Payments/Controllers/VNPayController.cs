using System.Text.Json.Serialization;
using CareSitter.Modules.Payments.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[AllowAnonymous]
public sealed class VNPayController(ISender sender) : ControllerBase
{
    [HttpGet("api/v1/payments/vnpay/ipn")]
    public async Task<IActionResult> Ipn(CancellationToken ct)
    {
        var result = await sender.Send(
            new ProcessVnPayIpnCommand(CallbackValues()), ct);
        return Ok(new VnPayIpnResponse(result.Code, result.Message));
    }

    [HttpGet("api/v1/payments/vnpay/return")]
    public async Task<IActionResult> Return(CancellationToken ct)
    {
        var result = await sender.Send(
            new ProcessVnPayReturnCommand(CallbackValues()), ct);
        return Redirect(result.RedirectUrl);
    }

    private Dictionary<string, string> CallbackValues() =>
        Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString(), StringComparer.Ordinal);

    private sealed record VnPayIpnResponse(
        [property: JsonPropertyName("RspCode")] string RspCode,
        [property: JsonPropertyName("Message")] string Message);
}
