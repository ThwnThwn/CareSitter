using CareSitter.Modules.Payments.Application.Refunds;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/refunds")]
public sealed class RefundsController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(
        string? status = "ALL",
        int page = 1,
        int pageSize = 20,
        CancellationToken ct = default) =>
        Ok(await mediator.Send(new ListRefundsQuery(status, page, pageSize), ct));

    /// <summary>
    /// Xác nhận một refund phải làm ngoài API sau khi đã đối chiếu provider/bank.
    /// Lệnh này mới ghi ledger; tạo request hoặc ảnh chụp không đủ để xác nhận.
    /// </summary>
    [HttpPost("{id:guid}/confirm")]
    public async Task<IActionResult> Confirm(
        Guid id,
        [FromBody] ConfirmRefundRequest request,
        CancellationToken ct)
    {
        var result = await mediator.Send(new ConfirmManualRefundCommand(
            id, request.ProviderRefundId, request.ConfirmationNote), ct);
        return result.ToActionResult(this);
    }
}
