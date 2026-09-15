using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.RaiseBookingSos;

internal sealed class RaiseBookingSosCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    BookingSyncService bookingSync,
    BookingPostCommitService postCommit,
    BookingResponseMapper responseMapper)
    : IRequestHandler<RaiseBookingSosCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(RaiseBookingSosCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();

        bool isCustomer = booking.CustomerId == userId;
        bool isAdmin = currentUser.IsInRole("ADMIN");
        bool isAssignedCaregiver = booking.CaregiverId.HasValue
            && await people.IsCaregiverForBookingAsync(booking.CaregiverId.Value, userId, ct);

        if (!isCustomer && !isAssignedCaregiver && !isAdmin)
            return BookingErrors.Forbidden();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.RaiseSos(userId);
        if (result.IsFailure) return result.Error;

        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, booking.CaregiverId, "SOS",
            "Cấp cứu / tình huống khẩn cấp", note: $"SOS raised by user {userId}"));
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CrisisRaised);
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("SOS status broadcast", () =>
            postCommit.BroadcastStatusAsync(request.BookingId, oldStatus,
                BookingStatusCodec.ToApi(booking.Status), ct));
        await postCommit.RunAsync("SOS customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("SOS notifications", () =>
            postCommit.NotifySosTargetsAsync(booking, userId, ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
