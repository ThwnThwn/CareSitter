using FluentValidation;

namespace CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;

public sealed class ListPendingPayoutsQueryValidator
    : AbstractValidator<ListPendingPayoutsQuery>
{
    private static readonly HashSet<string> AllowedStatuses =
    [
        "PENDING",
        "APPROVED",
        "REJECTED",
        "PROCESSING",
        "PAID",
        "FAILED",
        "ALL"
    ];

    public ListPendingPayoutsQueryValidator()
    {
        RuleFor(x => x.Page)
            .GreaterThanOrEqualTo(1)
            .WithErrorCode("payout.page")
            .WithMessage("page phải lớn hơn hoặc bằng 1.");
        RuleFor(x => x.PageSize)
            .InclusiveBetween(1, 50)
            .WithErrorCode("payout.page_size")
            .WithMessage("page_size phải nằm trong khoảng 1-50.");
        RuleFor(x => x.Status)
            .Must(status => string.IsNullOrWhiteSpace(status) ||
                            AllowedStatuses.Contains(status.Trim().ToUpperInvariant()))
            .WithErrorCode("payout.status_filter")
            .WithMessage("Trạng thái payout không hợp lệ.");
    }
}
