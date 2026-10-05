using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record ServiceCatalogResponse(
    Guid Id,
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool AllowAdHocTasks,
    long BaseHourlyPrice,
    decimal PlatformFeePercent);
