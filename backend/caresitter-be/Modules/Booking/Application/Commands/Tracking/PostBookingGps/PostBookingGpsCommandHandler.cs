using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

internal sealed class PostBookingGpsCommandHandler(
    IBookingTrackingStore bookings, ILiveLocationStore locations,
    IBookingTrackingNotifier notifier, IBookingPostCommitService postCommit,
    ICurrentUser user, IPeopleLookupService people,
    IOptionsMonitor<LiveTrackingOptions> options, IValidator<PostBookingGpsCommand> validator)
    : IRequestHandler<PostBookingGpsCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(PostBookingGpsCommand request, CancellationToken ct)
    {
        if (!options.CurrentValue.Enabled) return BookingErrors.GpsTrackingDisabled();
        if (user.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var validation = validator.Validate(request);
        if (!validation.IsValid)
            return Error.Validation("booking.gps.invalid_sample", "Tọa độ hoặc phiên GPS không hợp lệ.");
        var booking = await bookings.GetBookingAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct)) return BookingErrors.Forbidden();
        var result = await locations.WriteAsync(request, caregiverId, ct);
        if (result.IsFailure) return result.Error;
        if (result.Value is { } location)
            await postCommit.RunAsync("live GPS broadcast", () => notifier.GpsUpdatedAsync(booking.CustomerId, location, ct));
        return Unit.Value;
    }
}
