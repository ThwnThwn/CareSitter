using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;

public sealed record RequestBookingCheckoutCommand(Guid BookingId)
    : IRequest<Result<BookingResponse>>;
