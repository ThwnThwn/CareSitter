using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class ListAdminPromotionsQueryValidator : AbstractValidator<ListAdminPromotionsQuery>
{
    public ListAdminPromotionsQueryValidator()
    {
        RuleFor(x => x.Page).InclusiveBetween(1, 100_000).WithMessage("Số trang phải từ 1 đến 100.000.");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100).WithMessage("Mỗi trang từ 1 đến 100 chiến dịch.");
        RuleFor(x => x.Search).MaximumLength(160).WithMessage("Từ khóa tối đa 160 ký tự.");
        RuleFor(x => x.Status).Must(x => string.IsNullOrEmpty(x) ||
            new[] { "ACTIVE", "SCHEDULED", "EXPIRED", "INACTIVE" }.Contains(x))
            .WithMessage("Trạng thái chiến dịch không hợp lệ.");
    }
}
