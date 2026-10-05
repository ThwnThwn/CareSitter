using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record PricingRuleResponse(
    Guid Id,
    Guid ServiceTypeId,
    string Name,
    long BaseHourlyPrice,
    decimal NightMultiplier,
    decimal HolidayMultiplier,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive);
