using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.CheckInBooking;

public sealed record CheckInBookingCommand(
    Guid BookingId,
    double Latitude,
    double Longitude,
    double? AccuracyMeters = null) : IRequest<Result<BookingResponse>>;
