using CareSitter.Modules.Promotion.Domain;
using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class PromotionConfigurationValidator : AbstractValidator<PromotionConfiguration>
{
    public PromotionConfigurationValidator()
    {
        RuleFor(x => x).Custom((configuration, context) =>
        {
            var result = configuration.Validate();
            if (result.IsFailure) context.AddFailure(result.Error.Message);
        });
    }
}
