using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

public sealed record PostBookingGpsCommand(Guid BookingId) : IRequest<Result<Unit>>;
