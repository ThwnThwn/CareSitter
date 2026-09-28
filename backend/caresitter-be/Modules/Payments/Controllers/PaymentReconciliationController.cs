using CareSitter.Modules.Payments.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/payment-reconciliation")]
public sealed class PaymentReconciliationController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) =>
        Ok(await sender.Send(new ListPaymentReconciliationQuery(), ct));

    [HttpPost("{intentId:guid}/resolve")]
    public async Task<IActionResult> Resolve(
        Guid intentId, [FromBody] ResolvePaymentReviewRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new ResolvePaymentReviewCommand(
            intentId, request.Succeeded, request.Reason, request.ProviderTransactionId), ct);
        return result.ToActionResult(this, resolution =>
        {
            if (resolution.Finalization is { } finalization)
                return finalization.Succeeded ? Ok(finalization) : Conflict(finalization);
            return Ok(new { bookingId = resolution.BookingId, status = resolution.Status });
        });
    }
}

public sealed record ResolvePaymentReviewRequest(
    bool Succeeded, string Reason, string? ProviderTransactionId = null);
