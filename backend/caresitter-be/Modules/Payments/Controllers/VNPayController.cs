using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.VNPay.Dtos.Responses;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[AllowAnonymous]
public sealed class VNPayController : ControllerBase
{
    private readonly IMediator _mediator;

    public VNPayController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet("api/v1/payments/vnpay/ipn")]
    public async Task<IActionResult> Ipn(CancellationToken ct)
    {
        var result = await _mediator.Send(
            new ProcessVnPayIpnCommand(CallbackValues()), ct);
        return Ok(new VnPayIpnResponse(result.Code, result.Message));
    }

    [HttpGet("api/v1/payments/vnpay/return")]
    public async Task<IActionResult> Return(CancellationToken ct)
    {
        var result = await _mediator.Send(
            new ProcessVnPayReturnCommand(CallbackValues()), ct);
        return Redirect(result.RedirectUrl);
    }

    private Dictionary<string, string> CallbackValues() =>
        Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString(), StringComparer.Ordinal);

}
