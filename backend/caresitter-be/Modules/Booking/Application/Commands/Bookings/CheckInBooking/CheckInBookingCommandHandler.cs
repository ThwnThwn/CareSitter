using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.SharedKernel.ValueObjects;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Application.Commands.CheckInBooking;

internal sealed class CheckInBookingCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    ICatalogLookupService catalog,
    IOptions<CheckInOptions> checkInOptions,
    IValidator<CheckInBookingCommand> validator,
    IBookingSyncService bookingSync,
    IBookingChatWriter bookingChat,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<CheckInBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(CheckInBookingCommand request, CancellationToken ct)
    {
        var policy = checkInOptions.Value;
        var validation = validator.Validate(request);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode, validation.Errors[0].ErrorMessage);

        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BookingErrors.CaregiverMissing();
        if (!await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return BookingErrors.Forbidden();

        var addressLocation = await catalog.GetAddressLocationAsync(booking.AddressId, ct);
        if (addressLocation is null)
            return BookingErrors.AddressLocationMissing();

        var caregiverGeo = new GeoPoint(request.Latitude, request.Longitude);
        var addressGeo = new GeoPoint(addressLocation.Value.Lat, addressLocation.Value.Lng);

        var oldStatus = BookingStatusPresenter.ToApi(booking.Status);
        var result = booking.CheckIn(
            caregiverGeo,
            addressGeo,
            checkedInAt: DateTimeOffset.UtcNow,
            earlyWindow: TimeSpan.FromMinutes(policy.EarlyWindowMinutes),
            checkInRadiusMeters: policy.MaxDistanceMeters);
        if (result.IsFailure) return result.Error;

        double distance = caregiverGeo.DistanceMetersTo(addressGeo);
        string eventType = distance <= policy.MaxDistanceMeters
            ? "CHECKIN_VALID" : "CHECKIN_OUTSIDE_GEOFENCE";
        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, caregiverId, eventType, "Caregiver đã check-in",
            latitude: request.Latitude, longitude: request.Longitude,
            distanceToAddressMeters: distance));

        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CheckedIn);
        await bookingChat.RecordSystemTransitionAsync(booking,
            BookingSyncEventTypes.CheckedIn, "Caregiver đã đến và ca chăm sóc bắt đầu.",
            booking.ActualStart ?? DateTimeOffset.UtcNow, ct: ct);
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("check-in status broadcast", () =>
            postCommit.BroadcastStatusAsync(request.BookingId, oldStatus,
                BookingStatusPresenter.ToApi(booking.Status), ct));
        await postCommit.RunAsync("check-in customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("check-in customer notification", () =>
            postCommit.NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver đã check-in",
                "Ca chăm sóc đã bắt đầu.", ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
