using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class CreateServiceCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<CreateServiceCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(CreateServiceCommand request, CancellationToken ct)
    {
        var code = request.Code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (await repository.ServiceCodeExistsAsync(code, ct: ct))
            return Error.Conflict("catalog.service.code_exists", "Mã dịch vụ đã tồn tại.");

        var created = ServiceType.Create(code, request.Name, request.Description,
            request.DefaultDurationMinutes, request.IsActive);
        if (created.IsFailure) return created.Error;

        repository.Add(created.Value);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(created.Value);
        await auditLogger.WriteAsync("ADMIN_SERVICE_CREATED", "ServiceType", created.Value.Id,
            null, response, ct);
        return response;
    }
}

internal sealed class UpdateServiceCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<UpdateServiceCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(UpdateServiceCommand request, CancellationToken ct)
    {
        var service = await repository.GetServiceAsync(request.ServiceId, ct);
        if (service is null) return Error.NotFound("catalog.service.not_found", string.Empty);

        var code = request.Code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (await repository.ServiceCodeExistsAsync(code, request.ServiceId, ct))
            return Error.Conflict("catalog.service.code_exists", "Mã dịch vụ đã tồn tại.");

        var before = CatalogAdminMapper.ToResponse(service);
        var updated = service.Update(code, request.Name, request.Description, request.DefaultDurationMinutes);
        if (updated.IsFailure) return updated.Error;
        service.SetActive(request.IsActive);
        await repository.SaveChangesAsync(ct);

        var response = CatalogAdminMapper.ToResponse(service);
        await auditLogger.WriteAsync("ADMIN_SERVICE_UPDATED", "ServiceType", service.Id,
            before, response, ct);
        return response;
    }
}

internal sealed class SetServiceActiveCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<SetServiceActiveCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(SetServiceActiveCommand request, CancellationToken ct)
    {
        var service = await repository.GetServiceAsync(request.ServiceId, ct);
        if (service is null) return Error.NotFound("catalog.service.not_found", string.Empty);

        var before = CatalogAdminMapper.ToResponse(service);
        service.SetActive(request.IsActive);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(service);
        await auditLogger.WriteAsync("ADMIN_SERVICE_ACTIVE_UPDATED", "ServiceType", service.Id,
            before, response, ct);
        return response;
    }
}

internal sealed class CreatePricingRuleCommandHandler(
    ICatalogAdminRepository repository,
    ICurrentUser currentUser,
    IAuditLogger auditLogger) : IRequestHandler<CreatePricingRuleCommand, Result<PricingRuleResponse>>
{
    public async Task<Result<PricingRuleResponse>> Handle(CreatePricingRuleCommand request, CancellationToken ct)
    {
        if (!await repository.ServiceExistsAsync(request.ServiceId, ct))
            return Error.NotFound("catalog.service.not_found", string.Empty);

        var created = PricingRule.Create(request.Name, request.ServiceId, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, effectiveFrom: request.EffectiveFrom,
            effectiveTo: request.EffectiveTo, isActive: request.IsActive,
            createdByAdminId: currentUser.UserId);
        if (created.IsFailure) return created.Error;

        var validation = created.Value.Update(request.Name, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, request.EffectiveFrom, request.EffectiveTo);
        if (validation.IsFailure) return validation.Error;

        repository.Add(created.Value);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(created.Value);
        await auditLogger.WriteAsync("ADMIN_PRICING_RULE_CREATED", "PricingRule", created.Value.Id,
            null, response, ct);
        return response;
    }
}

internal sealed class UpdatePricingRuleCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<UpdatePricingRuleCommand, Result<PricingRuleResponse>>
{
    public async Task<Result<PricingRuleResponse>> Handle(UpdatePricingRuleCommand request, CancellationToken ct)
    {
        var rule = await repository.GetPricingRuleAsync(request.ServiceId, request.RuleId, ct);
        if (rule is null) return Error.NotFound("catalog.pricing_rule.not_found", string.Empty);

        var before = CatalogAdminMapper.ToResponse(rule);
        var updated = rule.Update(request.Name, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, request.EffectiveFrom, request.EffectiveTo);
        if (updated.IsFailure) return updated.Error;
        rule.SetActive(request.IsActive);
        await repository.SaveChangesAsync(ct);

        var response = CatalogAdminMapper.ToResponse(rule);
        await auditLogger.WriteAsync("ADMIN_PRICING_RULE_UPDATED", "PricingRule", rule.Id,
            before, response, ct);
        return response;
    }
}

internal sealed class SetPricingRuleActiveCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<SetPricingRuleActiveCommand, Result<PricingRuleResponse>>
{
    public async Task<Result<PricingRuleResponse>> Handle(SetPricingRuleActiveCommand request, CancellationToken ct)
    {
        var rule = await repository.GetPricingRuleAsync(request.ServiceId, request.RuleId, ct);
        if (rule is null) return Error.NotFound("catalog.pricing_rule.not_found", string.Empty);

        var before = CatalogAdminMapper.ToResponse(rule);
        rule.SetActive(request.IsActive);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(rule);
        await auditLogger.WriteAsync("ADMIN_PRICING_RULE_ACTIVE_UPDATED", "PricingRule", rule.Id,
            before, response, ct);
        return response;
    }
}
