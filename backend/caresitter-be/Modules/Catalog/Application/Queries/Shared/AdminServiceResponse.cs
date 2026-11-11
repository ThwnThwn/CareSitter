using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record AdminServiceResponse(
    Guid Id,
    string Code,
    string Name,
    string? Description,
    string? ImageUrl,
    int DefaultDurationMinutes,
    bool IsActive,
    bool AllowAdHocTasks,
    IReadOnlyList<PricingRuleResponse> PricingRules,
    IReadOnlyList<ServicePlanResponse> Plans);
