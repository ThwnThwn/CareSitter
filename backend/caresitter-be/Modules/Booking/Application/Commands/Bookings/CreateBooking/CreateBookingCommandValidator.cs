using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.CreateBooking;

public sealed class CreateBookingCommandValidator : AbstractValidator<CreateBookingCommand>
{
    public CreateBookingCommandValidator()
    {
        RuleFor(x => x.PromotionCode).MaximumLength(50);
    }
}
