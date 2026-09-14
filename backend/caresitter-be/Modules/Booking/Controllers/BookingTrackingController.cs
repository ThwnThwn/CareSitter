using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Controllers;

/// <summary>
/// Theo dõi thời gian thực của ca chăm sóc:
/// ghi timeline sự kiện (note, check-in, checkout...) và đọc GPS track lịch sử.
///
/// Phân quyền:
///   - Xem timeline/GPS: Customer của booking, Caregiver được assign, hoặc Admin.
///   - Ghi timeline note: Customer hoặc Caregiver được assign (trong ca đang diễn ra).
///   - Ghi GPS: chỉ Caregiver được assign.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/bookings/{id:guid}")]
public sealed class BookingTrackingController(
    BookingDbContext db,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IHubContext<CareTrackingHub> hub) : ControllerBase
{
    // ════════════════════════════════════════════
    //  TIMELINE
    // ════════════════════════════════════════════

    /// <summary>Lấy toàn bộ sự kiện timeline của booking, sắp xếp theo thời gian.</summary>
    [HttpGet("timeline")]
    public async Task<IActionResult> ListTimeline(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (!await CanView(booking, userId, ct)) return Forbid();

        var events = await db.TimelineEvents.AsNoTracking()
            .Where(x => x.BookingId == id)
            .OrderBy(x => x.RecordedAt)
            .ToListAsync(ct);

        return Ok(events.Select(e => new TimelineEventResponse(
            e.Id, e.BookingId, e.CaregiverId, e.TaskId, e.EventType,
            e.Title, e.Note, e.Latitude, e.Longitude,
            e.DistanceToAddressMeters, e.RecordedAt, e.Source)));
    }

    /// <summary>
    /// Thêm ghi chú (NOTE) vào timeline.
    /// Customer hoặc Caregiver được assign có thể thêm note khi booking đang diễn ra.
    /// </summary>
    [HttpPost("timeline")]
    public async Task<IActionResult> AddTimelineNote(Guid id, [FromBody] AddTimelineNoteRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (!await CanView(booking, userId, ct)) return Forbid();

        var caregiverId = booking.CaregiverId;

        var evt = CareTimelineEvent.Create(id, caregiverId, "NOTE",
            request.Title, request.Note, source: "ONLINE");
        db.TimelineEvents.Add(evt);
        await db.SaveChangesAsync(ct);

        // ── SignalR: broadcast timeline event mới cho tất cả viewer ──
        await hub.Clients
            .Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("TimelineEventAdded", new TimelineEventAddedEvent(
                id, caregiverId, evt.EventType, evt.Title, evt.Note,
                evt.Latitude, evt.Longitude, evt.RecordedAt), ct);

        return Created($"/api/v1/bookings/{id}/timeline/{evt.Id}",
            new TimelineEventResponse(evt.Id, evt.BookingId, evt.CaregiverId,
                evt.TaskId, evt.EventType, evt.Title, evt.Note,
                evt.Latitude, evt.Longitude, evt.DistanceToAddressMeters,
                evt.RecordedAt, evt.Source));
    }

    // ════════════════════════════════════════════
    //  GPS
    // ════════════════════════════════════════════

    /// <summary>
    /// Endpoint GPS tracking cũ. Không còn nhận điểm GPS định kỳ để tránh thu thập
    /// vị trí không cần thiết; GPS chỉ được kiểm tra ở endpoint check-in.
    /// </summary>
    [HttpPost("gps")]
    public IActionResult PostGps(Guid id)
    {
        return StatusCode(StatusCodes.Status410Gone, new
        {
            error = "GPS tracking liên tục đã bị tắt. Hệ thống chỉ dùng GPS lúc check-in để xác thực khoảng cách."
        });
    }

    /// <summary>
    /// Lấy điểm GPS mới nhất của caregiver trong booking.
    /// Customer, caregiver được assign, và Admin đều có thể xem.
    /// </summary>
    [HttpGet("gps/latest")]
    public async Task<IActionResult> GetLatestGps(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (!await CanView(booking, userId, ct)) return Forbid();

        var latest = await db.GpsTracks.AsNoTracking()
            .Where(x => x.BookingId == id)
            .OrderByDescending(x => x.RecordedAt)
            .FirstOrDefaultAsync(ct);

        if (latest is null) return NotFound();
        return Ok(new GpsTrackResponse(latest.Id, latest.BookingId, latest.CaregiverId,
            latest.Latitude, latest.Longitude, latest.AccuracyMeters,
            latest.Speed, latest.Heading, latest.RecordedAt));
    }

    /// <summary>
    /// Lấy toàn bộ lịch sử GPS track của booking để vẽ lộ trình trên bản đồ.
    /// Customer, caregiver được assign, và Admin đều có thể xem.
    /// </summary>
    [HttpGet("gps-tracks")]
    public async Task<IActionResult> ListGpsTracks(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (!await CanView(booking, userId, ct)) return Forbid();

        var tracks = await db.GpsTracks.AsNoTracking()
            .Where(x => x.BookingId == id)
            .OrderBy(x => x.RecordedAt)
            .ToListAsync(ct);

        return Ok(tracks.Select(t => new GpsTrackResponse(
            t.Id, t.BookingId, t.CaregiverId, t.Latitude, t.Longitude,
            t.AccuracyMeters, t.Speed, t.Heading, t.RecordedAt)));
    }

    // ── Helpers ──

    /// <summary>
    /// Kiểm tra user có quyền xem booking không.
    /// Cho phép: customer của booking, caregiver được assign, hoặc Admin.
    /// </summary>
    private async Task<bool> CanView(Domain.Booking booking, Guid userId, CancellationToken ct)
    {
        if (booking.CustomerId == userId) return true;
        if (currentUser.IsInRole("ADMIN")) return true;
        if (booking.CaregiverId.HasValue)
            return await people.IsCaregiverForBookingAsync(booking.CaregiverId.Value, userId, ct);
        return false;
    }
}

// ── DTOs ──
public sealed record AddTimelineNoteRequest(string? Title, string? Note);
public sealed record PostGpsRequest(double Latitude, double Longitude,
    double? AccuracyMeters = null, double? Speed = null, double? Heading = null);
public sealed record TimelineEventResponse(Guid Id, Guid BookingId, Guid? CaregiverId,
    Guid? TaskId, string EventType, string? Title, string? Note,
    double? Latitude, double? Longitude, double? DistanceToAddressMeters,
    DateTimeOffset RecordedAt, string Source);
public sealed record GpsTrackResponse(Guid Id, Guid BookingId, Guid CaregiverId,
    double Latitude, double Longitude, double? AccuracyMeters,
    double? Speed, double? Heading, DateTimeOffset RecordedAt);
