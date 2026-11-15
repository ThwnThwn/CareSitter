using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/bookings/{id:guid}")]
public sealed class BookingTrackingController : ControllerBase
{
    private readonly IMediator _mediator;

    public BookingTrackingController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet("timeline")]
    public async Task<IActionResult> ListTimeline(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new ListBookingTimelineQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpPost("timeline")]
    public async Task<IActionResult> AddTimelineNote(
        Guid id, [FromBody] AddTimelineNoteRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(
            new AddBookingTimelineNoteCommand(id, request.Title, request.Note), ct);
        return result.ToActionResult(this, value => Created(
            $"/api/v1/bookings/{id}/timeline/{value.Id}", value));
    }

    [HttpPost("gps")]
    [Authorize(Roles = "CAREGIVER")]
    [EnableRateLimiting("booking-gps")]
    public async Task<IActionResult> PostGps(Guid id, [FromBody] PostGpsRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new PostBookingGpsCommand(id, request.SessionId,
            request.Latitude, request.Longitude, request.CapturedAt,
            request.AccuracyMeters, request.Speed, request.Heading), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    [HttpPost("gps/session")]
    [Authorize(Roles = "CAREGIVER")]
    [EnableRateLimiting("booking-gps")]
    public async Task<IActionResult> OpenGpsSession(Guid id, [FromBody] OpenGpsSessionRequest request, CancellationToken ct)
    {
        Response.Headers.CacheControl = "no-store";
        var result = await _mediator.Send(new OpenGpsSessionCommand(id, request.SourceInstanceId), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("gps/latest")]
    public async Task<IActionResult> GetLatestGps(Guid id, CancellationToken ct)
    {
        Response.Headers.CacheControl = "no-store";
        var result = await _mediator.Send(new GetLatestBookingGpsQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("gps-tracks")]
    public async Task<IActionResult> ListGpsTracks(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new ListBookingGpsTracksQuery(id), ct);
        return result.ToActionResult(this);
    }
}
