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

    [HttpGet("messages/resume")]
    public async Task<IActionResult> ResumeMessagesAsync(
        Guid bookingId,
        [FromQuery] Guid anchorMessageId,
        [FromQuery] string direction,
        [FromQuery] long scopeVersion,
        [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        (await chat.ResumeMessagesAsync(bookingId, anchorMessageId, direction,
            scopeVersion, limit, ct)).ToActionResult(this);

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

    [HttpPost("messages/{messageId:guid}/reports")]
    public async Task<IActionResult> Report(
        Guid bookingId,
        Guid messageId,
        [FromBody] BookingChatReportRequest request,
        CancellationToken ct)
    {
        var result = await chat.ReportMessageAsync(bookingId, messageId, request, ct);
        return result.ToActionResult(this, report => report.Status == "LINKED"
            ? Ok(report)
            : Accepted($"/api/v1/bookings/{bookingId}/chat/reports/{report.ReportId}", report));
    }

    [HttpGet("reports/{reportId:guid}")]
    public async Task<IActionResult> GetReport(
        Guid bookingId,
        Guid reportId,
        CancellationToken ct) =>
        (await chat.GetReportAsync(bookingId, reportId, ct)).ToActionResult(this);

    [HttpPut("block")]
    public async Task<IActionResult> SetBlock(
        Guid bookingId,
        [FromBody] BookingChatBlockRequest request,
        CancellationToken ct) =>
        (await chat.SetBlockAsync(bookingId, request, ct)).ToActionResult(this);
}
