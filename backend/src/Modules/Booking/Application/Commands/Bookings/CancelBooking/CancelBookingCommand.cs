using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.CancelBooking;

public sealed record CancelBookingCommand(Guid BookingId, string? Reason)
    : IRequest<Result<BookingResponse>>;
