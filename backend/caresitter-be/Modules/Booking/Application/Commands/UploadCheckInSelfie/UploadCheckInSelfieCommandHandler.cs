using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

internal sealed class UploadCheckInSelfieCommandHandler(
    IBookingRepository bookings,
    IBookingMediaStore mediaStore,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMediaService mediaService,
    IValidator<UploadCheckInSelfieCommand> validator)
    : IRequestHandler<UploadCheckInSelfieCommand, Result<CheckInSelfieResponse>>
{
    public async Task<Result<CheckInSelfieResponse>> Handle(
        UploadCheckInSelfieCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var validation = validator.Validate(request);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode, validation.Errors[0].ErrorMessage);

        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return BookingErrors.Forbidden();
        if (booking.Status != BookingStatus.CaregiverEnRoute)
            return BookingErrors.SelfieInvalidState();

        var upload = await mediaService.UploadImageAsync(request.Content!, request.FileName,
            $"CareSitter/CheckIn/{booking.Id}", ct);
        if (upload.IsFailure) return upload.Error;

        var media = await mediaStore.AddPhotoAsync(
            userId, booking.Id, upload.Value, request.ContentType, request.Length, ct);
        if (media.IsFailure) return media.Error;

        bookings.AddTimelineEvent(CareTimelineEvent.Create(booking.Id, caregiverId, "PHOTO_UPLOADED",
            "Selfie check-in", taskId: null, source: "ONLINE").WithMedia(media.Value));
        await bookings.SaveChangesAsync(ct);
        return new CheckInSelfieResponse(media.Value, upload.Value, DateTimeOffset.UtcNow);
    }
}
