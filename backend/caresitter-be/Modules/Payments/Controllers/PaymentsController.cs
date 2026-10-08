using CareSitter.Modules.Payments.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Authorize]
public sealed class PaymentsController : ControllerBase
{
    private readonly IMediator _mediator;

    public PaymentsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost("api/v1/payments/intents")]
    public async Task<IActionResult> CreateIntent(
        [FromBody] CreatePaymentIntentRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(
            new CreatePaymentIntentCommand(request.BookingId, User.Identity?.Name, request.Provider), ct);
        return result.ToActionResult(this, outcome =>
        {
            if (outcome.Conflict is { } conflict)
            {
                if (conflict.PaymentDeadline is { } deadline)
                    return Conflict(new
                    {
                        error = conflict.Error,
                        conflict.Code,
                        paymentDeadline = deadline
                    });
                if (conflict.ExpiresAt is { } expiresAt)
                    return Conflict(new { error = conflict.Error, conflict.Code, expiresAt });
                return conflict.Code is null
                    ? Conflict(new { error = conflict.Error })
                    : Conflict(new { error = conflict.Error, conflict.Code });
            }

            return outcome.Created
                ? Created($"/api/v1/payments/intents/{outcome.Intent!.Id}", outcome.Intent)
                : Ok(outcome.Intent);
        });
    }

    [HttpGet("api/v1/payments/intents/{id:guid}")]
    public async Task<IActionResult> GetIntent(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetPaymentIntentQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("api/v1/payments/providers")]
    public async Task<IActionResult> ListProviders(CancellationToken ct) =>
        Ok(await _mediator.Send(new ListPaymentProvidersQuery(), ct));

    [HttpGet("api/v1/wallet")]
    public async Task<IActionResult> GetMyWallet(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetMyWalletQuery(), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("api/v1/wallet/transactions")]
    public async Task<IActionResult> ListMyWalletTransactions(
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(
            new ListMyWalletTransactionsQuery(page, pageSize), ct);
        return result.ToActionResult(this);
    }

    [Authorize(Roles = "ADMIN")]
    [HttpGet("api/v1/payments/ledger")]
    public async Task<IActionResult> ListLedger(
        Guid? bookingId = null, int page = 1, int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListLedgerQuery(bookingId, page, pageSize), ct);
        return result.ToActionResult(this);
    }
}
