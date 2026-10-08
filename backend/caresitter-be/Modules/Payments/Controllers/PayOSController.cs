using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[AllowAnonymous]
public sealed class PayOSController(IMediator mediator) : ControllerBase
{
    [HttpPost("api/v1/payments/payos/webhook")]
    [RequestSizeLimit(32 * 1024)]
    public async Task<IActionResult> Webhook([FromBody] JsonElement payload, CancellationToken ct)
    {
        var result = await mediator.Send(new ProcessPayOSWebhookCommand(payload), ct);
        return StatusCode(result.StatusCode, new { message = result.Message });
    }

    [HttpGet("api/v1/payments/payos/return")]
    [HttpGet("api/v1/payments/payos/cancel")]
    public async Task<IActionResult> Return([FromQuery] string? orderCode, CancellationToken ct) =>
        Redirect(await mediator.Send(new GetPayOSReturnQuery(orderCode), ct));
}
