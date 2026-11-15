using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.CompleteBooking;

public sealed record CompleteBookingCommand(Guid BookingId)
    : IRequest<Result<BookingResponse>>;
