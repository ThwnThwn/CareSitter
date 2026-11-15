using CareSitter.Modules.Support.Application.Commands.Notifications.ClaimNotificationDelivery;
using CareSitter.Modules.Support.Application.Commands.Notifications.CompleteNotificationDelivery;
using CareSitter.Modules.Support.Controllers.Contracts.Notifications;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>Service-key protected endpoints. The public edge proxy does not route this path.</summary>
[ApiController]
[Route("internal/messaging/notifications")]
[Authorize(AuthenticationSchemes = "MessagingService")]
public sealed class NotificationDeliveryController(IMediator mediator) : ControllerBase
{
    private readonly IMediator _mediator = mediator;

    /// <summary>Acquires a delivery lease and retrieves private provider input.</summary>
    [HttpPost("claim")]
    public async Task<IActionResult> Claim(ClaimNotificationDeliveryRequest request, CancellationToken ct)
    {
        Response.Headers.CacheControl = "no-store";
        return Ok(await _mediator.Send(new ClaimNotificationDeliveryCommand(request.EventId,
            request.NotificationId, request.RecipientId, request.Channel), ct));
    }

    /// <summary>Records the result only if the worker still owns the claim.</summary>
    [HttpPost("complete")]
    public async Task<IActionResult> Complete(CompleteNotificationDeliveryRequest request, CancellationToken ct) =>
        await _mediator.Send(new CompleteNotificationDeliveryCommand(request.EventId, request.Channel,
            request.ClaimToken, request.Succeeded, request.Failure), ct) ? NoContent() : Conflict();
}
