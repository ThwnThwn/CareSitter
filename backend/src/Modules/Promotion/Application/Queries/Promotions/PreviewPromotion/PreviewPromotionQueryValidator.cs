using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class PreviewPromotionQueryValidator : AbstractValidator<PreviewPromotionQuery>
{
    public PreviewPromotionQueryValidator()
    {
        RuleFor(x => x.Code).NotEmpty().MaximumLength(50);
        RuleFor(x => x.ServiceTypeId).NotEmpty();
        RuleFor(x => x.ScheduledEnd).GreaterThan(x => x.ScheduledStart);
    }
}
