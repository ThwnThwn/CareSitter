using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.CreateBooking;

public sealed class CreateBookingCommandValidator : AbstractValidator<CreateBookingCommand>
{
    public CreateBookingCommandValidator()
    {
        RuleFor(x => x.PromotionCode).MaximumLength(50);
        RuleFor(x => x.ExpectedPayableAmount).GreaterThan(0)
            .When(x => x.ExpectedPayableAmount.HasValue)
            .WithErrorCode("promotion.invalid_quote").WithMessage("Số tiền đã xác nhận phải lớn hơn 0đ.");
        RuleFor(x => x.RequiredSkills).Must(x => x is null ||
            x.Count <= 60 && x.All(s => !string.IsNullOrWhiteSpace(s) && s.Length <= 100))
            .WithErrorCode("care_needs.invalid").WithMessage("Nhu cầu chăm sóc không hợp lệ.");
    }
}
