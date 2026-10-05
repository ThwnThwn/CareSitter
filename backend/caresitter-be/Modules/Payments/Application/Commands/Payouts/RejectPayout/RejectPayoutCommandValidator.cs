using FluentValidation;

namespace CareSitter.Modules.Payments.Application.Payouts.RejectPayout;

public sealed class RejectPayoutCommandValidator
    : AbstractValidator<RejectPayoutCommand>
{
    public RejectPayoutCommandValidator()
    {
        RuleFor(x => x.PayoutId)
            .NotEmpty()
            .WithErrorCode("payout.id")
            .WithMessage("payout_id không hợp lệ.");
        RuleFor(x => x.Reason)
            .MaximumLength(500)
            .When(x => x.Reason is not null)
            .WithErrorCode("payout.reject_reason")
            .WithMessage("Lý do từ chối không được vượt quá 500 ký tự.");
    }
}
