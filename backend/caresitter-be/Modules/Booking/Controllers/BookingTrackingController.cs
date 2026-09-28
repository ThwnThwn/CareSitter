using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/bookings/{id:guid}")]
public sealed class BookingTrackingController(ISender sender) : ControllerBase
{
    [HttpGet("timeline")]
    public async Task<IActionResult> ListTimeline(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new ListBookingTimelineQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpPost("timeline")]
    public async Task<IActionResult> AddTimelineNote(
        Guid id, [FromBody] AddTimelineNoteRequest request, CancellationToken ct)
    {
        var result = await sender.Send(
            new AddBookingTimelineNoteCommand(id, request.Title, request.Note), ct);
        return result.ToActionResult(this, value => Created(
            $"/api/v1/bookings/{id}/timeline/{value.Id}", value));
    }

    [HttpPost("gps")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> PostGps(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new PostBookingGpsCommand(id), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    [HttpGet("gps/latest")]
    public async Task<IActionResult> GetLatestGps(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new GetLatestBookingGpsQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("gps-tracks")]
    public async Task<IActionResult> ListGpsTracks(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new ListBookingGpsTracksQuery(id), ct);
        return result.ToActionResult(this);
    }
}

public sealed record AddTimelineNoteRequest(string? Title, string? Note);
public sealed record PostGpsRequest(
    double Latitude, double Longitude, double? AccuracyMeters = null,
    double? Speed = null, double? Heading = null);
