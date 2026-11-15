using FluentValidation;

namespace CareSitter.Modules.Payments.Application.Payouts.CreatePayout;

public sealed class CreatePayoutCommandValidator
    : AbstractValidator<CreatePayoutCommand>
{
    public CreatePayoutCommandValidator()
    {
        RuleFor(x => x.Amount)
            .GreaterThanOrEqualTo(100_000)
            .WithErrorCode("payout.amount")
            .WithMessage("Số tiền rút tối thiểu là 100.000đ.");
        RuleFor(x => x.BankName)
            .Must(value => !string.IsNullOrWhiteSpace(value))
            .WithErrorCode("payout.bank_name")
            .WithMessage("bank_name không được rỗng.")
            .MaximumLength(255)
            .WithErrorCode("payout.bank_name")
            .WithMessage("bank_name tối đa 255 ký tự.");
        RuleFor(x => x.BankBin)
            .Matches("^[0-9]{6}$")
            .WithErrorCode("payout.bank_bin")
            .WithMessage("bank_bin phải gồm đúng 6 chữ số.");
        RuleFor(x => x.AccountHolderName)
            .Must(value => !string.IsNullOrWhiteSpace(value))
            .WithErrorCode("payout.account_holder_name")
            .WithMessage("account_holder_name không được rỗng.")
            .MaximumLength(255)
            .WithErrorCode("payout.account_holder_name")
            .WithMessage("account_holder_name tối đa 255 ký tự.");
        RuleFor(x => x.AccountNumber)
            .Must(value => !string.IsNullOrWhiteSpace(value))
            .WithErrorCode("payout.account_number")
            .WithMessage("account_number không được rỗng.")
            .Matches("^[0-9]{4,50}$")
            .WithErrorCode("payout.account_number")
            .WithMessage("account_number phải gồm 4-50 chữ số.");
        RuleFor(x => x).Custom((command, context) =>
        {
            var key = command.ResolveIdempotencyKey();
            if (key is null || key.Length > 100)
            {
                context.AddFailure(new FluentValidation.Results.ValidationFailure(
                    nameof(command.BodyIdempotencyKey),
                    "Thiếu hoặc sai idempotency key.")
                {
                    ErrorCode = "payout.idempotency_key"
                });
            }
        });
    }
}
