using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

public sealed record PostBookingGpsCommand(
    Guid BookingId, Guid SessionId = default, double Latitude = 0, double Longitude = 0,
    DateTimeOffset CapturedAt = default, double? AccuracyMeters = null,
    double? Speed = null, double? Heading = null) : IRequest<Result<Unit>>;
