using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Booking.Application;

public sealed record GpsTrackResponse(
    Guid Id, Guid BookingId, Guid CaregiverId, double Latitude, double Longitude,
    double? AccuracyMeters, double? Speed, double? Heading, DateTimeOffset RecordedAt,
    long Version = 0, Guid? SessionId = null, DateTimeOffset? ReceivedAt = null,
    long BookingVersion = 0)
{
    public DateTimeOffset CapturedAt => RecordedAt;
}
