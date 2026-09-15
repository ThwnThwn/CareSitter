using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;

internal sealed class StartBookingEnRouteCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    BookingSyncService bookingSync,
    BookingPostCommitService postCommit,
    BookingResponseMapper responseMapper)
    : IRequestHandler<StartBookingEnRouteCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(StartBookingEnRouteCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BookingErrors.CaregiverMissing();
        if (!await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return BookingErrors.Forbidden();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.StartEnRoute();
        if (result.IsFailure) return result.Error;
        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKIN", "Caregiver đang trên đường đến"));
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CaregiverEnRoute);
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("en-route status broadcast", () =>
            postCommit.BroadcastStatusAsync(request.BookingId, oldStatus,
                BookingStatusCodec.ToApi(booking.Status), ct));
        await postCommit.RunAsync("en-route customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("en-route customer notification", () =>
            postCommit.NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver đang di chuyển",
                "Caregiver đang trên đường đến địa điểm chăm sóc.", ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
