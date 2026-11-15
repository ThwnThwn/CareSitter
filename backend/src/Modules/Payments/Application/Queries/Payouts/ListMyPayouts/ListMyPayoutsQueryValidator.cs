using FluentValidation;

namespace CareSitter.Modules.Payments.Application.Payouts.ListMyPayouts;

public sealed class ListMyPayoutsQueryValidator
    : AbstractValidator<ListMyPayoutsQuery>
{
    public ListMyPayoutsQueryValidator()
    {
        RuleFor(x => x.Page)
            .GreaterThanOrEqualTo(1)
            .WithErrorCode("payout.page")
            .WithMessage("page phải lớn hơn hoặc bằng 1.");
        RuleFor(x => x.PageSize)
            .InclusiveBetween(1, 50)
            .WithErrorCode("payout.page_size")
            .WithMessage("page_size phải nằm trong khoảng 1-50.");
    }
}
