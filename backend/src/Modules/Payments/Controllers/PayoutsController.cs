using CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;
using CareSitter.Modules.Payments.Application.Payouts.CreatePayout;
using CareSitter.Modules.Payments.Application.Payouts.ListMyPayouts;
using CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;
using CareSitter.Modules.Payments.Application.Payouts.RejectPayout;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

/// <summary>
/// Quản lý các yêu cầu rút tiền của Caregiver từ ví điện tử.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/payments/payouts")]
public sealed class PayoutsController : ControllerBase
{
    private readonly IMediator _mediator;

    public PayoutsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>Caregiver tạo yêu cầu rút tiền từ available balance.</summary>
    [HttpPost]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> Create(
        [FromBody] CreatePayoutRequest request,
        [FromHeader(Name = "Idempotency-Key")] string? headerIdempotencyKey,
        CancellationToken ct)
    {
        var result = await _mediator.Send(new CreatePayoutCommand(
            request.Amount,
            request.BankName,
            request.BankBin,
            request.AccountHolderName,
            request.AccountNumber,
            request.IdempotencyKey,
            headerIdempotencyKey), ct);

        return result.ToActionResult(this, outcome => outcome.Created
            ? Created($"/api/v1/payments/payouts/{outcome.Payout.Id}", outcome.Payout)
            : Ok(outcome.Payout));
    }

    /// <summary>Caregiver xem lịch sử rút tiền của mình.</summary>
    [HttpGet]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> ListMy(
        int page = 1,
        int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListMyPayoutsQuery(page, pageSize), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin xem danh sách yêu cầu rút tiền.</summary>
    [HttpGet("pending")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ListPending(
        string? status = "PENDING",
        int page = 1,
        int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(
            new ListPendingPayoutsQuery(status, page, pageSize), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin duyệt yêu cầu rút tiền.</summary>
    [HttpPost("{id:guid}/approve")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> Approve(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new ApprovePayoutCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin từ chối yêu cầu rút tiền và hoàn lại số dư.</summary>
    [HttpPost("{id:guid}/reject")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> Reject(
        Guid id,
        [FromBody] RejectPayoutRequest? request,
        CancellationToken ct)
    {
        var result = await _mediator.Send(
            new RejectPayoutCommand(id, request?.Reason), ct);
        return result.ToActionResult(this);
    }
}
