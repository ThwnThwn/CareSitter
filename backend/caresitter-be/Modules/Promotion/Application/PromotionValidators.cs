using FluentValidation;

namespace CareSitter.Modules.Promotion.Application;

public sealed class PreviewPromotionCommandValidator : AbstractValidator<PreviewPromotionCommand>
{
    public PreviewPromotionCommandValidator()
    {
        RuleFor(x => x.Code).NotEmpty().MaximumLength(50);
        RuleFor(x => x.ServiceTypeId).NotEmpty();
        RuleFor(x => x.ScheduledEnd).GreaterThan(x => x.ScheduledStart);
    }
}
