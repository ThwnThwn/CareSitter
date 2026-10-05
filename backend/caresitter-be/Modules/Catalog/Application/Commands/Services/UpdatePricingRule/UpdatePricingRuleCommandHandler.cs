using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

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
