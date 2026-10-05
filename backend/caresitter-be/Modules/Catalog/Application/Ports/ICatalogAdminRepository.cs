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
