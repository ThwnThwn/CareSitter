using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;
using CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;
using CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý các yêu cầu hỗ trợ (Support Ticket) của người dùng.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/support/tickets")]
public sealed class SupportTicketsController : ControllerBase
{
    private readonly IMediator _mediator;

    public SupportTicketsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>User tao ticket ho tro (COMPLAINT, SOS, PAYMENT, KYC, CHECKOUT_REVIEW, GENERAL).</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateTicketRequest req, CancellationToken ct)
    {
        var result = await _mediator.Send(new CreateSupportTicketCommand(req.Type,
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
        var result = await _mediator.Send(new ListSupportTicketsQuery(
            status, type, priority, page, pageSize), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Xem chi tiet ticket (user chi xem cua minh, admin xem tat ca).</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetSupportTicketQuery(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin cap nhat trạng thái ticket (NEW -> IN_PROGRESS -> RESOLVED -> CLOSED).</summary>
    [HttpPut("{id:guid}/status")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateTicketStatusRequest req, CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdateSupportTicketStatusCommand(id, req.Status,
            req.ExpectedVersion, req.Reason), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin nhan xu ly ticket (assign admin va chuyen IN_PROGRESS).</summary>
    [HttpPut("{id:guid}/assign")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> Assign(Guid id,
        [FromHeader(Name = "X-Expected-Version")] long? expectedVersion, CancellationToken ct)
    {
        var result = await _mediator.Send(new AssignSupportTicketCommand(id, expectedVersion), ct);
        return result.ToActionResult(this);
    }

}
