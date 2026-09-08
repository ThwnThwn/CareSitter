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
/// Quản lý các yêu cầu hỗ trợ (Support Ticket) của người dùng.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/support/tickets")]
public sealed class SupportTicketsController(SupportDbContext db, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>User tao ticket ho tro (COMPLAINT, SOS, PAYMENT, KYC, CHECKOUT_REVIEW, GENERAL).</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateTicketRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var ticket = SupportTicket.Create(userId, req.Type, req.Priority ?? "MEDIUM", req.BookingId);
        if (ticket.IsFailure) return Problem(ticket.Error);

        db.SupportTickets.Add(ticket.Value);

        if (req.Type == "SOS" || req.Priority == "CRITICAL")
        {
            var notif = Notification.Create(userId, "SOS",
                "Ticket khan cap can xu ly",
                body: $"Ticket {ticket.Value.Id} - {req.Type}",
                data: $"{{\"ticket_id\":\"{ticket.Value.Id}\"}}");
            if (notif.IsSuccess) db.Notifications.Add(notif.Value);
        }

        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/support/tickets/{ticket.Value.Id}",
            ToResponse(ticket.Value));
    }

    /// <summary>
    /// User xem ticket cua minh. Admin xem tat ca (co loc theo status/type/priority).
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> List(string? status = null, string? type = null,
        string? priority = null, int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var query = db.SupportTickets.AsNoTracking().AsQueryable();

        if (!currentUser.IsInRole("ADMIN"))
            query = query.Where(x => x.UserId == userId);

        if (!string.IsNullOrWhiteSpace(status))
            query = query.Where(x => x.Status == status.ToUpper());
        if (!string.IsNullOrWhiteSpace(type))
            query = query.Where(x => x.Type == type.ToUpper());
        if (!string.IsNullOrWhiteSpace(priority))
            query = query.Where(x => x.Priority == priority.ToUpper());

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(x => new TicketResponse(x.Id, x.UserId, x.BookingId,
                x.Type, x.Status, x.Priority, x.AssignedAdminId, x.CreatedAt, x.UpdatedAt))
            .ToListAsync(ct);

        return Ok(new { items, total, page, pageSize });
    }

    /// <summary>Xem chi tiet ticket (user chi xem cua minh, admin xem tat ca).</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var ticket = await db.SupportTickets.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (ticket is null) return NotFound();

        if (!currentUser.IsInRole("ADMIN") && ticket.UserId != userId)
            return Forbid();

        return Ok(ToResponse(ticket));
    }

    /// <summary>Admin cap nhat trang thai ticket (NEW -> IN_PROGRESS -> RESOLVED -> CLOSED).</summary>
    [HttpPut("{id:guid}/status")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateTicketStatusRequest req, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();

        var ticket = await db.SupportTickets.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (ticket is null) return NotFound();

        var result = ticket.UpdateStatus(req.Status);
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(ticket));
    }

    /// <summary>Admin nhan xu ly ticket (assign admin va chuyen IN_PROGRESS).</summary>
    [HttpPut("{id:guid}/assign")]
    public async Task<IActionResult> Assign(Guid id, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        if (currentUser.UserId is not { } adminId) return Unauthorized();

        var ticket = await db.SupportTickets.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (ticket is null) return NotFound();

        var result = ticket.AssignAdmin(adminId);
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(ticket));
    }

    private static TicketResponse ToResponse(SupportTicket t) => new(t.Id, t.UserId,
        t.BookingId, t.Type, t.Status, t.Priority, t.AssignedAdminId, t.CreatedAt, t.UpdatedAt);

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

public sealed record CreateTicketRequest(string Type, string? Priority = "MEDIUM",
    Guid? BookingId = null);
public sealed record UpdateTicketStatusRequest(string Status);
public sealed record TicketResponse(Guid Id, Guid UserId, Guid? BookingId,
    string Type, string Status, string Priority, Guid? AssignedAdminId,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
