using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

internal interface ILiveLocationStore
{
    Task<Result<LiveTrackingSessionResponse>> OpenSessionAsync(Guid bookingId, Guid caregiverId, Guid sourceInstanceId, CancellationToken ct);
    Task<Result<GpsTrackResponse?>> WriteAsync(PostBookingGpsCommand sample, Guid caregiverId, CancellationToken ct);
    Task<GpsTrackResponse?> GetLatestAsync(Guid bookingId, CancellationToken ct);
    Task<int> DeleteExpiredBatchAsync(CancellationToken ct);
}
