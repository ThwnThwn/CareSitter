using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class CatalogLookupService(CatalogDbContext db) : ICatalogLookupService
{
    public Task<bool> AddressBelongsToAsync(Guid addressId, Guid customerId,
        CancellationToken ct = default) => db.Addresses.AsNoTracking()
        .AnyAsync(x => x.Id == addressId && x.OwnerUserId == customerId, ct);

    public Task<bool> ServiceIsActiveAsync(Guid serviceTypeId, CancellationToken ct = default) =>
        db.ServiceTypes.AsNoTracking().AnyAsync(x => x.Id == serviceTypeId && x.IsActive, ct);

    public async Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid addressId, CancellationToken ct = default)
    {
        var address = await db.Addresses.AsNoTracking()
            .Where(x => x.Id == addressId)
            .Select(x => x.Location)
            .FirstOrDefaultAsync(ct);
        if (address is null) return null;
        return (address.Y, address.X); // NTS Point: X = longitude, Y = latitude
    }
}

