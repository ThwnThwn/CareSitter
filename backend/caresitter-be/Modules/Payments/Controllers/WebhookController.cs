using CareSitter.Modules.Payments.Application;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Route("api/v1/payments/webhook")]
public sealed class WebhookController : ControllerBase
{
    private readonly IMediator _mediator;

    public WebhookController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
    public async Task<IActionResult> Handle([FromBody] WebhookRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new ProcessPaymentWebhookCommand(
            request.Provider, request.ProviderEventId, request.EventType,
            request.ProviderTransactionId, request.ProviderOrderRef, request.Payload), ct);
        return result.ToActionResult(this);
    }
}
