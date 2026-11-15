using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class ListBookingGpsTracksQueryHandler(
    IBookingTrackingStore store, ICurrentUser currentUser, IPeopleLookupService people)
    : IRequestHandler<ListBookingGpsTracksQuery, Result<IReadOnlyList<GpsTrackResponse>>>
{
    public async Task<Result<IReadOnlyList<GpsTrackResponse>>> Handle(
        ListBookingGpsTracksQuery request, CancellationToken ct)
    {
        var access = await BookingTrackingAccess.GetAuthorizedBookingAsync(
            request.BookingId, store, currentUser, people, ct);
        if (access.IsFailure) return access.Error;
        return Result.Success(await store.ListGpsAsync(request.BookingId, ct));
    }
}
