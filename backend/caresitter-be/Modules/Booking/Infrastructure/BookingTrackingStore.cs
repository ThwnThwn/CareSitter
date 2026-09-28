using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingTrackingStore(BookingDbContext db) : IBookingTrackingStore
{
    public Task<Domain.Booking?> GetBookingAsync(
        Guid bookingId, CancellationToken ct = default) =>
        db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == bookingId, ct);

    public async Task<IReadOnlyList<TimelineEventResponse>> ListTimelineAsync(
        Guid bookingId, CancellationToken ct = default) =>
        await db.TimelineEvents.AsNoTracking().Where(x => x.BookingId == bookingId)
            .OrderBy(x => x.RecordedAt).Select(x => new TimelineEventResponse(
                x.Id, x.BookingId, x.CaregiverId, x.TaskId, x.EventType,
                x.Title, x.Note, x.Latitude, x.Longitude, x.DistanceToAddressMeters,
                x.RecordedAt, x.Source)).ToListAsync(ct);

    public async Task<TimelineEventResponse> AddTimelineNoteAsync(
        Guid bookingId, Guid? caregiverId, string? title, string? note,
        CancellationToken ct = default)
    {
        var timelineEvent = CareTimelineEvent.Create(
            bookingId, caregiverId, "NOTE", title, note, source: "ONLINE");
        db.TimelineEvents.Add(timelineEvent);
        await db.SaveChangesAsync(ct);
        return ToResponse(timelineEvent);
    }

    public async Task<GpsTrackResponse?> GetLatestGpsAsync(
        Guid bookingId, CancellationToken ct = default)
    {
        var track = await db.GpsTracks.AsNoTracking().Where(x => x.BookingId == bookingId)
            .OrderByDescending(x => x.RecordedAt).FirstOrDefaultAsync(ct);
        return track is null ? null : ToResponse(track);
    }

    public async Task<IReadOnlyList<GpsTrackResponse>> ListGpsAsync(
        Guid bookingId, CancellationToken ct = default)
    {
        var tracks = await db.GpsTracks.AsNoTracking().Where(x => x.BookingId == bookingId)
            .OrderBy(x => x.RecordedAt).ToListAsync(ct);
        return tracks.Select(ToResponse).ToArray();
    }

    private static TimelineEventResponse ToResponse(CareTimelineEvent value) => new(
        value.Id, value.BookingId, value.CaregiverId, value.TaskId, value.EventType,
        value.Title, value.Note, value.Latitude, value.Longitude,
        value.DistanceToAddressMeters, value.RecordedAt, value.Source);
    private static GpsTrackResponse ToResponse(GpsTrack value) => new(
        value.Id, value.BookingId, value.CaregiverId, value.Latitude, value.Longitude,
        value.AccuracyMeters, value.Speed, value.Heading, value.RecordedAt);
}

internal sealed class BookingTrackingNotifier(IHubContext<CareTrackingHub> hub)
    : IBookingTrackingNotifier
{
    public Task TimelineAddedAsync(
        TimelineEventResponse value, CancellationToken ct = default) =>
        hub.Clients.Group(CareTrackingHub.BookingGroup(value.BookingId))
            .SendAsync("TimelineEventAdded", new TimelineEventAddedEvent(
                value.BookingId, value.CaregiverId, value.EventType, value.Title,
                value.Note, value.Latitude, value.Longitude, value.RecordedAt), ct);
}
