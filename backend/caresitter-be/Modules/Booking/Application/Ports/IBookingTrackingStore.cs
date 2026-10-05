using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

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
