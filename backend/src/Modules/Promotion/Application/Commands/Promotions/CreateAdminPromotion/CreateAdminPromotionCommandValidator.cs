using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class CreateAdminPromotionCommandValidator : AbstractValidator<CreateAdminPromotionCommand>
{
    public CreateAdminPromotionCommandValidator()
    {
        RuleFor(x => x.Configuration).NotNull().SetValidator(new PromotionConfigurationValidator());
    }
}
