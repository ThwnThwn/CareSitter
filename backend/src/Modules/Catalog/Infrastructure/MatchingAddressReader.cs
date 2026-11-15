using CareSitter.Contracts.Services;
using CareSitter.Contracts.Services.Routing;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class MatchingAddressReader(CatalogDbContext db) : IMatchingAddressReader
{
    public async Task<MatchingAddress?> GetAsync(
        Guid addressId, CancellationToken ct = default)
    {
        var address = await db.Addresses.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == addressId, ct);
        return address is null
            ? null
            : new MatchingAddress(
                address.District,
                address.City,
                new GeoPoint(address.Location.Y, address.Location.X));
    }
}
