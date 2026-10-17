using CareSitter.Modules.Booking.Application.BookingChat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController]
[Authorize(Roles = "CUSTOMER,CAREGIVER")]
[Route("api/v1/bookings/{bookingId:guid}/chat")]
public sealed class BookingChatController(IBookingChatService chat) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMetadata(Guid bookingId, CancellationToken ct)
    {
        var result = await chat.GetMetadataAsync(bookingId, ct);
        return result.ToActionResult(this);
    }

    [HttpGet("messages")]
    public async Task<IActionResult> GetMessages(
        Guid bookingId,
        [FromQuery] string? afterCursor,
        [FromQuery] string? beforeCursor,
        [FromQuery] int limit = 50,
        CancellationToken ct = default)
    {
        var result = await chat.GetMessagesAsync(
            bookingId, afterCursor, beforeCursor, limit, ct);
        return result.ToActionResult(this);
    }

    [HttpPost("messages")]
    [RequestSizeLimit(16 * 1024)]
    public async Task<IActionResult> Send(
        Guid bookingId,
        [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey,
        [FromBody] BookingChatSendRequest request,
        CancellationToken ct)
    {
        if (!Guid.TryParse(idempotencyKey, out var key))
            return BadRequest(new ProblemDetails
            {
                Title = "booking.chat.invalid_idempotency_key",
                Detail = "Idempotency-Key phải là UUID hợp lệ."
            });
        var result = await chat.SendAsync(bookingId, key, request, ct);
        return result.ToActionResult(this, message =>
            Created($"/api/v1/bookings/{bookingId}/chat/messages/{message.Id}", message));
    }

    [HttpPut("read")]
    public async Task<IActionResult> MarkRead(
        Guid bookingId,
        [FromBody] BookingChatReadRequest request,
        CancellationToken ct)
    {
        var result = await chat.MarkReadAsync(bookingId, request, ct);
        return result.ToActionResult(this);
    }
}
