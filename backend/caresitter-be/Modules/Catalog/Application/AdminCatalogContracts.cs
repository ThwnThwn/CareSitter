using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public interface ICatalogAdminRepository
{
    Task<bool> ServiceCodeExistsAsync(string code, Guid? exceptServiceId = null,
        CancellationToken ct = default);

    Task<bool> ServiceExistsAsync(Guid serviceId, CancellationToken ct = default);
    Task<ServiceType?> GetServiceAsync(Guid serviceId, CancellationToken ct = default);
    Task<PricingRule?> GetPricingRuleAsync(Guid serviceId, Guid ruleId,
        CancellationToken ct = default);

    void Add(ServiceType service);
    void Add(PricingRule pricingRule);
    Task SaveChangesAsync(CancellationToken ct = default);
}

public sealed record CreateServiceCommand(
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool IsActive) : IRequest<Result<AdminServiceResponse>>;

public sealed record UpdateServiceCommand(
    Guid ServiceId,
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool IsActive) : IRequest<Result<AdminServiceResponse>>;

public sealed record SetServiceActiveCommand(
    Guid ServiceId,
    bool IsActive) : IRequest<Result<AdminServiceResponse>>;

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

public sealed record UpdatePricingRuleCommand(
    Guid ServiceId,
    Guid RuleId,
    string Name,
    long BaseHourlyPrice,
    decimal NightMultiplier,
    decimal HolidayMultiplier,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive) : IRequest<Result<PricingRuleResponse>>;

public sealed record SetPricingRuleActiveCommand(
    Guid ServiceId,
    Guid RuleId,
    bool IsActive) : IRequest<Result<PricingRuleResponse>>;

internal static class CatalogAdminMapper
{
    public static AdminServiceResponse ToResponse(ServiceType service) => new(
        service.Id, service.Code, service.Name, service.Description,
        service.DefaultDurationMinutes, service.IsActive, service.AllowAdHocTasks, []);

    public static PricingRuleResponse ToResponse(PricingRule rule) => new(
        rule.Id, rule.ServiceTypeId, rule.Name, rule.BaseHourlyPrice,
        rule.NightMultiplier, rule.HolidayMultiplier, rule.PlatformFeePercent,
        rule.DisputeWindowHours, rule.EffectiveFrom, rule.EffectiveTo, rule.IsActive);
}
