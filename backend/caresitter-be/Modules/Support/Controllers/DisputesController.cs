using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CancelDispute;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.Modules.Support.Application.Commands.ResolveDispute;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý khiếu nại (Disputes) liên quan đến Booking.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/disputes")]
public sealed class DisputesController(ISender sender) : ControllerBase
{
    [HttpGet("/api/v1/admin/disputes")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ListForAdmin(string? status = null,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        var result = await sender.Send(new ListAdminDisputesQuery(status, page, pageSize), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("/api/v1/admin/disputes/{id:guid}")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> GetForAdmin(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new GetAdminDisputeQuery(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Khách hàng tạo khiếu nại cho booking thuộc sở hữu trong dispute window.</summary>
    [HttpPost]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> Create([FromBody] CreateDisputeRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new CreateDisputeCommand(
            req.BookingId, req.Reason, req.Description), ct);
        return result.ToActionResult(this,
            dispute => Created($"/api/v1/disputes/{dispute.Id}", dispute));
    }

    /// <summary>Lấy danh sách khiếu nại mà user hiện tại đã tạo.</summary>
    [HttpGet]
    [Authorize(Roles = "CUSTOMER,CAREGIVER")]
    public async Task<IActionResult> ListMy(CancellationToken ct)
    {
        var result = await sender.Send(new ListMyDisputesQuery(), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Xem chi tiết một khiếu nại của user.</summary>
    [HttpGet("{id:guid}")]
    [Authorize(Roles = "CUSTOMER,CAREGIVER")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new GetMyDisputeQuery(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin ra phan quyet dispute va ghi refund/penalty vao ledger.</summary>
    [HttpPost("{id:guid}/resolve")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> Resolve(Guid id, [FromBody] ResolveDisputeRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new ResolveDisputeCommand(id,
            req.Decision, req.RefundAmount, req.CaregiverPenaltyAmount), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin huy dispute.</summary>
    [HttpPost("{id:guid}/cancel")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new CancelDisputeCommand(id), ct);
        return result.ToActionResult(this);
    }
}

public sealed record CreateDisputeRequest(Guid BookingId, string? Reason = null,
    string? Description = null);
public sealed record ResolveDisputeRequest(string Decision, long? RefundAmount = null,
    long? CaregiverPenaltyAmount = null);
