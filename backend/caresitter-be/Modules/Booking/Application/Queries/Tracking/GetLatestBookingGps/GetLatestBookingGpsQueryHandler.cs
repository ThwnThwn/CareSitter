using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Application;

internal sealed class GetLatestBookingGpsQueryHandler(
    IBookingTrackingStore store,
    ILiveLocationStore locations,
    IOptionsMonitor<LiveTrackingOptions> options,
    ICurrentUser currentUser,
    IPeopleLookupService people)
    : IRequestHandler<GetLatestBookingGpsQuery, Result<GpsTrackResponse>>
{
    public async Task<Result<GpsTrackResponse>> Handle(GetLatestBookingGpsQuery request, CancellationToken ct)
    {
        var access = await BookingTrackingAccess.GetAuthorizedBookingAsync(
            request.BookingId, store, currentUser, people, ct);
        if (access.IsFailure) return access.Error;
        if (!options.CurrentValue.Enabled) return BookingErrors.GpsTrackingDisabled();
        var gps = await locations.GetLatestAsync(request.BookingId, ct);
        // Assignment can change between authorization and the location snapshot.
        // A previously assigned caregiver must never receive their replacement's fix.
        if (gps is not null && currentUser.UserId != access.Value.CustomerId &&
            !currentUser.IsInRole("ADMIN") && gps.CaregiverId != access.Value.CaregiverId)
            return BookingErrors.Forbidden();
        return gps is null
            ? Error.NotFound("booking.gps.no_location", "Chưa có vị trí trực tiếp cho ca này.")
            : gps;
    }
}
