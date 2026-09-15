using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;

public sealed record StartBookingEnRouteCommand(Guid BookingId)
    : IRequest<Result<BookingResponse>>;
