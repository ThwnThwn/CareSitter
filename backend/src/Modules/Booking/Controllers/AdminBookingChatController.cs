using CareSitter.Modules.Booking.Application.BookingChat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/booking-chats")]
public sealed class AdminBookingChatController(IBookingChatAdminService chat) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] BookingChatAdminListFilter filter,
        [FromQuery] string? cursor, [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        (await chat.ListAsync(filter, cursor, limit, ct)).ToActionResult(this);

    [HttpGet("{conversationId:guid}")]
    public async Task<IActionResult> Get(Guid conversationId, [FromQuery] string reason,
        [FromQuery] Guid? ticketId, CancellationToken ct) =>
        (await chat.GetAsync(conversationId, reason, ticketId, ct)).ToActionResult(this);

    [HttpGet("{conversationId:guid}/messages")]
    public async Task<IActionResult> Messages(Guid conversationId, [FromQuery] long? beforeSequence,
        [FromQuery] int limit, [FromQuery] string reason, [FromQuery] Guid? ticketId,
        CancellationToken ct = default) =>
        (await chat.GetMessagesAsync(
            conversationId, beforeSequence, limit == 0 ? 50 : limit, reason, ticketId, ct))
        .ToActionResult(this);

    [HttpGet("{conversationId:guid}/activities")]
    public async Task<IActionResult> Activity(Guid conversationId, [FromQuery] string? cursor,
        [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        (await chat.GetActivityAsync(conversationId, cursor, limit, ct)).ToActionResult(this);

    [HttpPut("{conversationId:guid}/block")]
    public async Task<IActionResult> Block(Guid conversationId, [FromBody] BookingChatAdminBlockRequest request,
        CancellationToken ct) => (await chat.BlockAsync(conversationId, request, ct)).ToActionResult(this);

    [HttpPut("{conversationId:guid}/unblock")]
    public async Task<IActionResult> Unblock(Guid conversationId, [FromBody] BookingChatAdminBlockRequest request,
        CancellationToken ct) => (await chat.UnblockAsync(conversationId, request, ct)).ToActionResult(this);

    [HttpPut("{conversationId:guid}/legal-hold/release")]
    public async Task<IActionResult> ReleaseLegalHold(Guid conversationId,
        [FromBody] BookingChatAdminBlockRequest request, CancellationToken ct) =>
        (await chat.ReleaseLegalHoldAsync(conversationId, request, ct)).ToActionResult(this);
}
