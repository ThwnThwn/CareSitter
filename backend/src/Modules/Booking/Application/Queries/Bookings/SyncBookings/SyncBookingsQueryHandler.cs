using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class SyncBookingsQueryHandler(
    IBookingReadStore store,
    ICurrentUser currentUser,
    IClock clock,
    IBookingSyncService bookingSync,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<SyncBookingsQuery, Result<BookingSyncResponse>>
{
    public async Task<Result<BookingSyncResponse>> Handle(SyncBookingsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();
        if (!currentUser.IsInRole("CUSTOMER") && !currentUser.IsInRole("ADMIN"))
            return BookingErrors.Forbidden();

        var delta = await bookingSync.GetDeltaAsync(userId, request.Cursor, 100, ct);
        if (delta.ResetRequired)
            return new BookingSyncResponse(null, 0, clock.UtcNow, null, true);

        if (delta.Events.Count == 0)
            return new BookingSyncResponse([], delta.NextCursor, clock.UtcNow, false, false);

        var ids = delta.Events.Select(x => x.BookingId).Distinct().ToArray();
        var bookings = await store.GetManyAsync(ids, ct);
        var responses = await responseMapper.ToResponsesAsync(bookings, ct);
        return new BookingSyncResponse(
            responses, delta.NextCursor, clock.UtcNow, delta.HasMore, false);
    }
}
