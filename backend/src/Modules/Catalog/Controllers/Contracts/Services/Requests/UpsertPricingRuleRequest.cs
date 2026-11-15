using CareSitter.Modules.Catalog.Application;

namespace CareSitter.Modules.Catalog.Controllers;

public sealed record UpsertPricingRuleRequest(
    string Name,
    long BaseHourlyPrice,
    decimal NightMultiplier,
    decimal HolidayMultiplier,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive = true);
