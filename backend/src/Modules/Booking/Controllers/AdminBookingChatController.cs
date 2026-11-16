using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Application.Commands.BookingChat;
using CareSitter.Modules.Booking.Application.Queries.BookingChat;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/booking-chats")]
public sealed class AdminBookingChatController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] BookingChatAdminListFilter filter,
        [FromQuery] string? cursor, [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        (await sender.Send(new ListAdminBookingChatsQuery(filter, cursor, limit), ct)).ToActionResult(this);

    [HttpGet("{conversationId:guid}")]
    public async Task<IActionResult> Get(Guid conversationId, [FromQuery] string reason,
        [FromQuery] Guid? ticketId, CancellationToken ct) =>
        (await sender.Send(new ViewAdminBookingChatCommand(conversationId, reason, ticketId), ct)).ToActionResult(this);

    [HttpGet("{conversationId:guid}/messages")]
    public async Task<IActionResult> Messages(Guid conversationId, [FromQuery] long? beforeSequence,
        [FromQuery] int limit, [FromQuery] string reason, [FromQuery] Guid? ticketId,
        CancellationToken ct = default) =>
        (await sender.Send(new ViewAdminBookingChatMessagesCommand(
            conversationId, beforeSequence, limit == 0 ? 50 : limit, reason, ticketId), ct))
        .ToActionResult(this);

    [HttpGet("{conversationId:guid}/activities")]
    public async Task<IActionResult> Activity(Guid conversationId, [FromQuery] string? cursor,
        [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        (await sender.Send(new ListAdminBookingChatActivitiesQuery(conversationId, cursor, limit), ct)).ToActionResult(this);

    [HttpPut("{conversationId:guid}/block")]
    public async Task<IActionResult> Block(Guid conversationId, [FromBody] BookingChatAdminBlockRequest request,
        CancellationToken ct) =>
        (await sender.Send(new BlockAdminBookingChatCommand(conversationId, request), ct)).ToActionResult(this);

    [HttpPut("{conversationId:guid}/unblock")]
    public async Task<IActionResult> Unblock(Guid conversationId, [FromBody] BookingChatAdminBlockRequest request,
        CancellationToken ct) =>
        (await sender.Send(new UnblockAdminBookingChatCommand(conversationId, request), ct)).ToActionResult(this);

    [HttpPut("{conversationId:guid}/legal-hold/release")]
    public async Task<IActionResult> ReleaseLegalHold(Guid conversationId,
        [FromBody] BookingChatAdminBlockRequest request, CancellationToken ct) =>
        (await sender.Send(new ReleaseBookingChatLegalHoldCommand(conversationId, request), ct)).ToActionResult(this);
}
