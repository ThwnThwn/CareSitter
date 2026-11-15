using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Application;

internal sealed class OpenGpsSessionHandler(
    IBookingTrackingStore bookings, ILiveLocationStore locations,
    ICurrentUser user, IPeopleLookupService people, IOptionsMonitor<LiveTrackingOptions> options)
    : IRequestHandler<OpenGpsSessionCommand, Result<LiveTrackingSessionResponse>>
{
    public async Task<Result<LiveTrackingSessionResponse>> Handle(OpenGpsSessionCommand request, CancellationToken ct)
    {
        if (!options.CurrentValue.Enabled) return BookingErrors.GpsTrackingDisabled();
        if (user.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (request.SourceInstanceId == Guid.Empty)
            return Error.Validation("booking.gps.source_required", "Thiếu định danh phiên gửi vị trí.");
        var booking = await bookings.GetBookingAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct)) return BookingErrors.Forbidden();
        return await locations.OpenSessionAsync(request.BookingId, caregiverId, request.SourceInstanceId, ct);
    }
}
