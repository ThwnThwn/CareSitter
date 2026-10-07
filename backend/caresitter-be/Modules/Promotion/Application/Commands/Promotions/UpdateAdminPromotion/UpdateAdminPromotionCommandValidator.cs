using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class UpdateAdminPromotionCommandValidator : AbstractValidator<UpdateAdminPromotionCommand>
{
    public UpdateAdminPromotionCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.ExpectedUpdatedAt).NotEmpty().WithMessage("Vui lòng tải lại chiến dịch trước khi thay đổi.");
        RuleFor(x => x.Configuration).NotNull().SetValidator(new PromotionConfigurationValidator());
    }
}
