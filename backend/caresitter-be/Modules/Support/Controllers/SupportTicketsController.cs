using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;
using CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;
using CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý các yêu cầu hỗ trợ (Support Ticket) của người dùng.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/support/tickets")]
public sealed class SupportTicketsController(
    SupportDbContext db, ICurrentUser currentUser, ISender sender) : ControllerBase
{
    /// <summary>User tao ticket ho tro (COMPLAINT, SOS, PAYMENT, KYC, CHECKOUT_REVIEW, GENERAL).</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateTicketRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new CreateSupportTicketCommand(req.Type,
            req.Title, req.Description, req.Priority, req.BookingId, req.AttachmentUrls), ct);
        return result.ToActionResult(this,
            ticket => Created($"/api/v1/support/tickets/{ticket.Id}", ticket));
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
                x.Type, x.Status, x.Priority, x.Title, x.Description,
                x.AttachmentUrls, x.AssignedAdminId, x.CreatedAt, x.UpdatedAt))
            .ToListAsync(ct);

        return Ok(new
        {
            items = items.Select(ToApiResponse),
            total,
            page,
            pageSize
        });
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

    /// <summary>Admin cap nhat trạng thái ticket (NEW -> IN_PROGRESS -> RESOLVED -> CLOSED).</summary>
    [HttpPut("{id:guid}/status")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateTicketStatusRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new UpdateSupportTicketStatusCommand(id, req.Status), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin nhan xu ly ticket (assign admin va chuyen IN_PROGRESS).</summary>
    [HttpPut("{id:guid}/assign")]
    public async Task<IActionResult> Assign(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new AssignSupportTicketCommand(id), ct);
        return result.ToActionResult(this);
    }

    private static object ToResponse(SupportTicket t) => ToApiResponse(new TicketResponse(
        t.Id, t.UserId, t.BookingId, t.Type, t.Status, t.Priority,
        t.Title, t.Description, t.AttachmentUrls, t.AssignedAdminId, t.CreatedAt, t.UpdatedAt));

    private static object ToApiResponse(TicketResponse t) => new
    {
        t.Id,
        t.UserId,
        t.BookingId,
        t.Type,
        t.Status,
        t.Priority,
        t.Title,
        t.Description,
        AttachmentUrls = DeserializeUrls(t.AttachmentUrlsJson),
        t.AssignedAdminId,
        t.CreatedAt,
        t.UpdatedAt
    };

    private static string[] DeserializeUrls(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<string>();
        try { return JsonSerializer.Deserialize<string[]>(json) ?? Array.Empty<string>(); }
        catch (JsonException) { return Array.Empty<string>(); }
    }

}

public sealed record CreateTicketRequest(
    string Type,
    string Title,
    string Description,
    string? Priority = "MEDIUM",
    Guid? BookingId = null,
    string[]? AttachmentUrls = null);
public sealed record UpdateTicketStatusRequest(string Status);
public sealed record TicketResponse(Guid Id, Guid UserId, Guid? BookingId,
    string Type, string Status, string Priority, string Title, string Description,
    string? AttachmentUrlsJson, Guid? AssignedAdminId,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
