using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class ListBookingTimelineQueryHandler(
    IBookingTrackingStore store, ICurrentUser currentUser, IPeopleLookupService people)
    : IRequestHandler<ListBookingTimelineQuery, Result<IReadOnlyList<TimelineEventResponse>>>
{
    public async Task<Result<IReadOnlyList<TimelineEventResponse>>> Handle(
        ListBookingTimelineQuery request, CancellationToken ct)
    {
        var access = await BookingTrackingAccess.GetAuthorizedBookingAsync(
            request.BookingId, store, currentUser, people, ct);
        if (access.IsFailure) return access.Error;
        return Result.Success(await store.ListTimelineAsync(request.BookingId, ct));
    }
}
