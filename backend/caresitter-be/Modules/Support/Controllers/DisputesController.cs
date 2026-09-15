using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CancelDispute;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.Modules.Support.Application.Commands.ResolveDispute;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý khiếu nại (Disputes) liên quan đến Booking.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/disputes")]
public sealed class DisputesController(
    SupportDbContext db, ICurrentUser currentUser, ISender sender) : ControllerBase
{
    /// <summary>Khách hàng hoặc Caregiver tạo khiếu nại cho một booking.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateDisputeRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new CreateDisputeCommand(
            req.BookingId, req.Reason, req.Description), ct);
        return result.ToActionResult(this,
            dispute => Created($"/api/v1/disputes/{dispute.Id}", dispute));
    }

    /// <summary>Lấy danh sách khiếu nại mà user hiện tại đã tạo.</summary>
    [HttpGet]
    public async Task<IActionResult> ListMy(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var items = await db.Disputes.AsNoTracking()
            .Where(x => x.RaisedByUserId == userId)
            .OrderByDescending(x => x.OpenedAt)
            .ToListAsync(ct);
        return Ok(items.Select(d => new DisputeResponse(d.Id, d.BookingId,
            d.RaisedByUserId, d.Reason, d.Description, d.Status, d.Decision,
            d.RefundAmount, d.OpenedAt, d.ResolvedAt)));
    }

    /// <summary>Xem chi tiết một khiếu nại của user.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var d = await db.Disputes.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.RaisedByUserId == userId, ct);
        if (d is null) return NotFound();
        return Ok(new DisputeResponse(d.Id, d.BookingId, d.RaisedByUserId,
            d.Reason, d.Description, d.Status, d.Decision, d.RefundAmount,
            d.OpenedAt, d.ResolvedAt));
    }

    /// <summary>Admin ra phan quyet dispute va ghi refund/penalty vao ledger.</summary>
    [HttpPost("{id:guid}/resolve")]
    public async Task<IActionResult> Resolve(Guid id, [FromBody] ResolveDisputeRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new ResolveDisputeCommand(id,
            req.Decision, req.RefundAmount, req.CaregiverPenaltyAmount), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin huy dispute.</summary>
    [HttpPost("{id:guid}/cancel")]
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
