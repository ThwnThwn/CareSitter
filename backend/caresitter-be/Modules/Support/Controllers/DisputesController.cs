using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using CareSitter.SharedKernel.Results;
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
    SupportDbContext db, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Khách hàng hoặc Caregiver tạo khiếu nại cho một booking.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateDisputeRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        bool exists = await db.Disputes.AnyAsync(x => x.BookingId == req.BookingId, ct);
        if (exists) return Conflict(new { error = "Booking nay da co dispute." });

        var created = Dispute.Create(req.BookingId, userId, req.Reason, req.Description);
        if (created.IsFailure) return Problem(created.Error);

        db.Disputes.Add(created.Value);
        await db.SaveChangesAsync(ct);
        var d = created.Value;
        return Created($"/api/v1/disputes/{d.Id}",
            new DisputeResponse(d.Id, d.BookingId, d.RaisedByUserId, d.Reason, d.Description,
                d.Status, d.Decision, d.RefundAmount, d.OpenedAt, d.ResolvedAt));
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
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        if (currentUser.UserId is not { } adminId) return Unauthorized();

        var dispute = await db.Disputes.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (dispute is null) return NotFound();

        var result = dispute.Resolve(adminId, req.Decision, req.RefundAmount, req.CaregiverPenaltyAmount);
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        var d = dispute;
        return Ok(new DisputeResponse(d.Id, d.BookingId, d.RaisedByUserId,
            d.Reason, d.Description, d.Status, d.Decision, d.RefundAmount,
            d.OpenedAt, d.ResolvedAt));
    }

    /// <summary>Admin huy dispute.</summary>
    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();

        var dispute = await db.Disputes.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (dispute is null) return NotFound();

        var result = dispute.Cancel();
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        var d = dispute;
        return Ok(new DisputeResponse(d.Id, d.BookingId, d.RaisedByUserId,
            d.Reason, d.Description, d.Status, d.Decision, d.RefundAmount,
            d.OpenedAt, d.ResolvedAt));
    }

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

public sealed record CreateDisputeRequest(Guid BookingId, string? Reason = null,
    string? Description = null);
public sealed record DisputeResponse(Guid Id, Guid BookingId, Guid RaisedByUserId,
    string? Reason, string? Description, string Status, string? Decision,
    long? RefundAmount, DateTimeOffset OpenedAt, DateTimeOffset? ResolvedAt);
public sealed record ResolveDisputeRequest(string Decision, long? RefundAmount = null,
    long? CaregiverPenaltyAmount = null);
