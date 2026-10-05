using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record AdminServiceResponse(
    Guid Id,
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool IsActive,
    bool AllowAdHocTasks,
    IReadOnlyList<PricingRuleResponse> PricingRules);
