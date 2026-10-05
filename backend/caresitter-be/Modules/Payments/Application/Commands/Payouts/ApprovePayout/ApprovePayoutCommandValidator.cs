using FluentValidation;

namespace CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;

public sealed class ApprovePayoutCommandValidator
    : AbstractValidator<ApprovePayoutCommand>
{
    public ApprovePayoutCommandValidator()
    {
        RuleFor(x => x.PayoutId)
            .NotEmpty()
            .WithErrorCode("payout.id")
            .WithMessage("payout_id không hợp lệ.");
    }
}
