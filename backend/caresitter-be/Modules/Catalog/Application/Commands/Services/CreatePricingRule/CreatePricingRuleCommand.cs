using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record CreatePricingRuleCommand(
    Guid ServiceId,
    string Name,
    long BaseHourlyPrice,
    decimal NightMultiplier,
    decimal HolidayMultiplier,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive) : IRequest<Result<PricingRuleResponse>>;
