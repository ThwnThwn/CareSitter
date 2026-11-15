using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class CatalogAdminRepository(CatalogDbContext db) : ICatalogAdminRepository
{
    public Task<bool> ServiceCodeExistsAsync(string code, Guid? exceptServiceId = null,
        CancellationToken ct = default) => db.ServiceTypes.AnyAsync(
        x => x.Code == code && (!exceptServiceId.HasValue || x.Id != exceptServiceId.Value), ct);

    public Task<bool> ServiceExistsAsync(Guid serviceId, CancellationToken ct = default) =>
        db.ServiceTypes.AsNoTracking().AnyAsync(x => x.Id == serviceId, ct);

    public Task<ServiceType?> GetServiceAsync(Guid serviceId, CancellationToken ct = default) =>
        db.ServiceTypes.SingleOrDefaultAsync(x => x.Id == serviceId, ct);

    public Task<PricingRule?> GetPricingRuleAsync(Guid serviceId, Guid ruleId,
        CancellationToken ct = default) => db.PricingRules.SingleOrDefaultAsync(
        x => x.Id == ruleId && x.ServiceTypeId == serviceId, ct);

    public void Add(ServiceType service) => db.ServiceTypes.Add(service);
    public void Add(PricingRule pricingRule) => db.PricingRules.Add(pricingRule);
    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
