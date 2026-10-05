using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingTrackingAccess
{
    internal static async Task<Result<Domain.Booking>> GetAuthorizedBookingAsync(
        Guid bookingId,
        IBookingTrackingStore store,
        ICurrentUser currentUser,
        IPeopleLookupService people,
        CancellationToken ct)
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
