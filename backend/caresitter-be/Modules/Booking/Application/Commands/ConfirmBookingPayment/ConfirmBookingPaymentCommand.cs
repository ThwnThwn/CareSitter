using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.ConfirmBookingPayment;

public sealed record ConfirmBookingPaymentCommand(Guid BookingId)
    : IRequest<Result<BookingResponse>>;
