using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

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

        repository.Add(created.Value);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(created.Value);
        await auditLogger.WriteAsync("ADMIN_PRICING_RULE_CREATED", "PricingRule", created.Value.Id,
            null, response, ct);
        return response;
    }
}
