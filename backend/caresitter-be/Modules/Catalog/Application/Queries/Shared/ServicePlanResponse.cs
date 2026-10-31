using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record ServicePlanResponse(
    Guid Id,
    Guid ServiceTypeId,
    string Code,
    string Name,
    string? Description,
    string BillingUnit,
    int DurationMinutes,
    int IncludedSessions,
    long TotalPrice,
    int? ValidityDays,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    int SortOrder,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive);
