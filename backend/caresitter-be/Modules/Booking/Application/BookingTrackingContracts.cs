using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record TimelineEventResponse(
    Guid Id, Guid BookingId, Guid? CaregiverId, Guid? TaskId, string EventType,
    string? Title, string? Note, double? Latitude, double? Longitude,
    double? DistanceToAddressMeters, DateTimeOffset RecordedAt, string Source);
public sealed record GpsTrackResponse(
    Guid Id, Guid BookingId, Guid CaregiverId, double Latitude, double Longitude,
    double? AccuracyMeters, double? Speed, double? Heading, DateTimeOffset RecordedAt);

public sealed record ListBookingTimelineQuery(Guid BookingId)
    : IRequest<Result<IReadOnlyList<TimelineEventResponse>>>;
public sealed record AddBookingTimelineNoteCommand(
    Guid BookingId, string? Title, string? Note) : IRequest<Result<TimelineEventResponse>>;
public sealed record GetLatestBookingGpsQuery(Guid BookingId)
    : IRequest<Result<GpsTrackResponse>>;
public sealed record ListBookingGpsTracksQuery(Guid BookingId)
    : IRequest<Result<IReadOnlyList<GpsTrackResponse>>>;

internal interface IBookingTrackingStore
{
    Task<Domain.Booking?> GetBookingAsync(Guid bookingId, CancellationToken ct = default);
    Task<IReadOnlyList<TimelineEventResponse>> ListTimelineAsync(
        Guid bookingId, CancellationToken ct = default);
    Task<TimelineEventResponse> AddTimelineNoteAsync(
        Guid bookingId, Guid? caregiverId, string? title, string? note,
        CancellationToken ct = default);
    Task<GpsTrackResponse?> GetLatestGpsAsync(Guid bookingId, CancellationToken ct = default);
    Task<IReadOnlyList<GpsTrackResponse>> ListGpsAsync(
        Guid bookingId, CancellationToken ct = default);
}

internal interface IBookingTrackingNotifier
{
    Task TimelineAddedAsync(TimelineEventResponse timelineEvent, CancellationToken ct = default);
}

internal sealed class BookingTrackingHandlers(
    IBookingTrackingStore store,
    IBookingTrackingNotifier notifier,
    ICurrentUser currentUser,
    IPeopleLookupService people) :
    IRequestHandler<ListBookingTimelineQuery, Result<IReadOnlyList<TimelineEventResponse>>>,
    IRequestHandler<AddBookingTimelineNoteCommand, Result<TimelineEventResponse>>,
    IRequestHandler<GetLatestBookingGpsQuery, Result<GpsTrackResponse>>,
    IRequestHandler<ListBookingGpsTracksQuery, Result<IReadOnlyList<GpsTrackResponse>>>
{
    public async Task<Result<IReadOnlyList<TimelineEventResponse>>> Handle(
        ListBookingTimelineQuery request, CancellationToken ct)
    {
        var access = await GetAuthorizedBooking(request.BookingId, ct);
        if (access.IsFailure) return access.Error;
        return Result.Success(await store.ListTimelineAsync(request.BookingId, ct));
    }

    public async Task<Result<TimelineEventResponse>> Handle(
        AddBookingTimelineNoteCommand request, CancellationToken ct)
    {
        var access = await GetAuthorizedBooking(request.BookingId, ct);
        if (access.IsFailure) return access.Error;
        var timelineEvent = await store.AddTimelineNoteAsync(
            request.BookingId, access.Value.CaregiverId, request.Title, request.Note, ct);
        await notifier.TimelineAddedAsync(timelineEvent, ct);
        return timelineEvent;
    }

    public async Task<Result<GpsTrackResponse>> Handle(
        GetLatestBookingGpsQuery request, CancellationToken ct)
    {
        var access = await GetAuthorizedBooking(request.BookingId, ct);
        if (access.IsFailure) return access.Error;
        var gps = await store.GetLatestGpsAsync(request.BookingId, ct);
        return gps is null ? BookingErrors.NotFound() : gps;
    }

    public async Task<Result<IReadOnlyList<GpsTrackResponse>>> Handle(
        ListBookingGpsTracksQuery request, CancellationToken ct)
    {
        var access = await GetAuthorizedBooking(request.BookingId, ct);
        if (access.IsFailure) return access.Error;
        return Result.Success(await store.ListGpsAsync(request.BookingId, ct));
    }

    private async Task<Result<Domain.Booking>> GetAuthorizedBooking(
        Guid bookingId, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await store.GetBookingAsync(bookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CustomerId == userId || currentUser.IsInRole("ADMIN")) return booking;
        if (booking.CaregiverId is { } caregiverId &&
            await people.IsCaregiverForBookingAsync(caregiverId, userId, ct)) return booking;
        return BookingErrors.Forbidden();
    }
}
