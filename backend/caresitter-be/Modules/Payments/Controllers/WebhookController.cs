using CareSitter.Modules.Payments.Application;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Route("api/v1/payments/webhook")]
public sealed class WebhookController(ISender sender) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Handle([FromBody] WebhookRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new ProcessPaymentWebhookCommand(
            request.Provider, request.ProviderEventId, request.EventType,
            request.ProviderTransactionId, request.ProviderOrderRef, request.Payload), ct);
        return result.ToActionResult(this);
    }
}

public sealed record WebhookRequest(
    string Provider,
    string ProviderEventId,
    string? EventType = null,
    string? ProviderTransactionId = null,
    string? ProviderOrderRef = null,
    string? Payload = null);
