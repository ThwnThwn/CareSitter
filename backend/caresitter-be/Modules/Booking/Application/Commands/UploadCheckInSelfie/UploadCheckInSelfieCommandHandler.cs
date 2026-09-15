using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

internal sealed class UploadCheckInSelfieCommandHandler(
    IBookingRepository bookings,
    IBookingMediaAssetRepository mediaAssets,
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
        var file = request.File!;

        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return BookingErrors.Forbidden();
        if (booking.Status != BookingStatus.CaregiverEnRoute)
            return BookingErrors.SelfieInvalidState();

        await using var stream = file.OpenReadStream();
        var upload = await mediaService.UploadImageAsync(stream, file.FileName,
            $"CareSitter/CheckIn/{booking.Id}", ct);
        if (upload.IsFailure) return upload.Error;

        var assetResult = MediaAsset.Create("CLOUDINARY", "caresitter", upload.Value, "PHOTO",
            ownerUserId: userId, bookingId: booking.Id, url: upload.Value,
            mimeType: file.ContentType, sizeBytes: file.Length);
        if (assetResult.IsFailure) return assetResult.Error;
        await mediaAssets.AddAndSaveAsync(assetResult.Value, ct);

        bookings.AddTimelineEvent(CareTimelineEvent.Create(booking.Id, caregiverId, "PHOTO_UPLOADED",
            "Selfie check-in", taskId: null, source: "ONLINE").WithMedia(assetResult.Value.Id));
        await bookings.SaveChangesAsync(ct);
        return new CheckInSelfieResponse(assetResult.Value.Id, upload.Value, DateTimeOffset.UtcNow);
    }
}
