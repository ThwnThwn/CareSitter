using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;

public sealed class RequestBookingCheckoutCommandValidator
    : AbstractValidator<RequestBookingCheckoutCommand>;
