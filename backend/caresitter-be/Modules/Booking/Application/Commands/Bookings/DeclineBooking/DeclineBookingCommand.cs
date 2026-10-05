using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.DeclineBooking;

public sealed record DeclineBookingCommand(Guid BookingId, string? Reason)
    : IRequest<Result<Unit>>;
