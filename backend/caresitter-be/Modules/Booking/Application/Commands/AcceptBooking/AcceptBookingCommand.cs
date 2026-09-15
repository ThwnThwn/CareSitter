using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.AcceptBooking;

public sealed record AcceptBookingCommand(Guid BookingId) : IRequest<Result<BookingResponse>>;
