using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class SetAdminPromotionActiveCommandValidator : AbstractValidator<SetAdminPromotionActiveCommand>
{
    public SetAdminPromotionActiveCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ExpectedUpdatedAt).NotEmpty().WithMessage("Vui lòng tải lại chiến dịch trước khi thay đổi.");
    }
}
