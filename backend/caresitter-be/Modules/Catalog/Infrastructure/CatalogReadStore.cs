using CareSitter.Modules.Catalog.Application;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class CatalogReadStore(CatalogDbContext db) : ICatalogReadStore
{
    public async Task<IReadOnlyList<ServiceCatalogResponse>> ListActiveServicesAsync(
        DateTimeOffset now, CancellationToken ct = default)
    {
        var items = await db.ServiceTypes.AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.DefaultDurationMinutes)
            .ThenBy(x => x.Name)
            .Select(x => new
            {
                x.Id,
                x.Code,
                x.Name,
                x.Description,
                x.ImageUrl,
                x.DefaultDurationMinutes,
                x.AllowAdHocTasks,
                Pricing = db.PricingRules.AsNoTracking()
                    .Where(p => p.ServiceTypeId == x.Id && p.IsActive &&
                        p.EffectiveFrom <= now && (p.EffectiveTo == null || p.EffectiveTo > now))
                    .OrderByDescending(p => p.EffectiveFrom)
                    .Select(p => new { p.BaseHourlyPrice, p.PlatformFeePercent })
                    .FirstOrDefault()
            })
            .ToListAsync(ct);

        var plans = await db.ServicePlans.AsNoTracking()
            .Where(x => x.IsActive &&
                db.ServiceTypes.Any(service => service.Id == x.ServiceTypeId && service.IsActive) &&
                x.EffectiveFrom <= now && (x.EffectiveTo == null || x.EffectiveTo > now))
            .OrderBy(x => x.SortOrder)
            .ThenBy(x => x.IncludedSessions)
            .ToListAsync(ct);

        return items.Select(x => new ServiceCatalogResponse(
            x.Id, x.Code, x.Name, x.Description, x.ImageUrl, x.DefaultDurationMinutes,
            x.AllowAdHocTasks, x.Pricing?.BaseHourlyPrice ?? 0,
            x.Pricing?.PlatformFeePercent ?? 0m,
            plans.Where(plan => plan.ServiceTypeId == x.Id)
                .Select(CatalogAdminMapper.ToResponse).ToArray())).ToArray();
    }

    public async Task<ServiceCatalogResponse?> GetActiveServiceAsync(
        Guid serviceId, DateTimeOffset now, CancellationToken ct = default)
    {
        var item = await db.ServiceTypes.AsNoTracking()
            .Where(x => x.Id == serviceId && x.IsActive)
            .Select(x => new
            {
                x.Id,
                x.Code,
                x.Name,
                x.Description,
                x.ImageUrl,
                x.DefaultDurationMinutes,
                x.AllowAdHocTasks
            })
            .SingleOrDefaultAsync(ct);
        if (item is null) return null;

        var pricing = await db.PricingRules.AsNoTracking()
            .Where(p => p.ServiceTypeId == serviceId && p.IsActive &&
                p.EffectiveFrom <= now && (p.EffectiveTo == null || p.EffectiveTo > now))
            .OrderByDescending(p => p.EffectiveFrom)
            .Select(p => new { p.BaseHourlyPrice, p.PlatformFeePercent })
            .FirstOrDefaultAsync(ct);

        var plans = await db.ServicePlans.AsNoTracking()
            .Where(x => x.ServiceTypeId == serviceId && x.IsActive &&
                x.EffectiveFrom <= now && (x.EffectiveTo == null || x.EffectiveTo > now))
            .OrderBy(x => x.SortOrder)
            .ThenBy(x => x.IncludedSessions)
            .ToListAsync(ct);

        return new ServiceCatalogResponse(item.Id, item.Code, item.Name, item.Description,
            item.ImageUrl,
            item.DefaultDurationMinutes, item.AllowAdHocTasks,
            pricing?.BaseHourlyPrice ?? 0, pricing?.PlatformFeePercent ?? 0m,
            plans.Select(CatalogAdminMapper.ToResponse).ToArray());
    }

    public async Task<IReadOnlyList<AddressResponse>> ListOwnedAddressesAsync(
        Guid ownerUserId, CancellationToken ct = default)
    {
        var addresses = await db.Addresses.AsNoTracking()
            .Where(x => x.OwnerUserId == ownerUserId)
            .OrderByDescending(x => x.UpdatedAt)
            .ToListAsync(ct);
        return addresses.Select(CatalogResponseMapper.ToResponse).ToArray();
    }

    public async Task<AddressResponse?> GetOwnedAddressAsync(
        Guid addressId, Guid ownerUserId, CancellationToken ct = default)
    {
        var address = await db.Addresses.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == addressId && x.OwnerUserId == ownerUserId, ct);
        return address is null ? null : CatalogResponseMapper.ToResponse(address);
    }

    public async Task<IReadOnlyList<AdminServiceResponse>> ListAdminServicesAsync(
        CancellationToken ct = default)
    {
        var services = await db.ServiceTypes.AsNoTracking().OrderBy(x => x.Name).ToListAsync(ct);
        var prices = await db.PricingRules.AsNoTracking()
            .OrderByDescending(x => x.EffectiveFrom)
            .ToListAsync(ct);
        var plans = await db.ServicePlans.AsNoTracking()
            .OrderBy(x => x.SortOrder)
            .ThenBy(x => x.IncludedSessions)
            .ToListAsync(ct);

        return services.Select(service => new AdminServiceResponse(
            service.Id, service.Code, service.Name, service.Description, service.ImageUrl,
            service.DefaultDurationMinutes, service.IsActive, service.AllowAdHocTasks,
            prices.Where(x => x.ServiceTypeId == service.Id)
                .Select(CatalogAdminMapper.ToResponse).ToArray(),
            plans.Where(x => x.ServiceTypeId == service.Id)
                .Select(CatalogAdminMapper.ToResponse).ToArray())).ToArray();
    }

    public async Task<AdminServiceResponse?> GetAdminServiceAsync(
        Guid serviceId, CancellationToken ct = default)
    {
        var service = await db.ServiceTypes.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == serviceId, ct);
        if (service is null) return null;

        var prices = await db.PricingRules.AsNoTracking()
            .Where(x => x.ServiceTypeId == serviceId)
            .OrderByDescending(x => x.EffectiveFrom)
            .ToListAsync(ct);
        var plans = await db.ServicePlans.AsNoTracking()
            .Where(x => x.ServiceTypeId == serviceId)
            .OrderBy(x => x.SortOrder)
            .ThenBy(x => x.IncludedSessions)
            .ToListAsync(ct);

        return new AdminServiceResponse(
            service.Id, service.Code, service.Name, service.Description, service.ImageUrl,
            service.DefaultDurationMinutes, service.IsActive, service.AllowAdHocTasks,
            prices.Select(CatalogAdminMapper.ToResponse).ToArray(),
            plans.Select(CatalogAdminMapper.ToResponse).ToArray());
    }
}
