using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class GetBookingQueryHandler(
    IBookingReadStore store,
    ICurrentUser currentUser,
    IClock clock,
    IPeopleLookupService people,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<GetBookingQuery, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(GetBookingQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();
        var booking = await store.GetAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();

        var canRead = booking.CustomerId == userId || currentUser.IsInRole("ADMIN");
        if (!canRead && currentUser.IsInRole("CAREGIVER"))
        {
            var caregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
            canRead = caregiverId.HasValue &&
                (booking.CaregiverId == caregiverId.Value ||
                 await store.HasActiveCaregiverAccessAsync(
                     booking.Id, caregiverId.Value, clock.UtcNow, ct));
        }

        if (!canRead) return BookingErrors.Forbidden();
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
