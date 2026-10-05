using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

namespace CareSitter.Modules.Booking.Controllers;

public sealed record PostGpsRequest(
    double Latitude, double Longitude, double? AccuracyMeters = null,
    double? Speed = null, double? Heading = null,
    Guid SessionId = default, DateTimeOffset CapturedAt = default);
