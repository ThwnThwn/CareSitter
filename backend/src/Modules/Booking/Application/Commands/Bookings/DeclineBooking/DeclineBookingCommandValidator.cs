using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.DeclineBooking;

public sealed class DeclineBookingCommandValidator : AbstractValidator<DeclineBookingCommand>
{
    public DeclineBookingCommandValidator()
    {
        RuleFor(x => x.Reason)
            .MaximumLength(200)
            .WithErrorCode(BookingErrors.DeclineReasonTooLongCode)
            .WithMessage("Lý do từ chối tối đa 200 ký tự.");
    }
}
