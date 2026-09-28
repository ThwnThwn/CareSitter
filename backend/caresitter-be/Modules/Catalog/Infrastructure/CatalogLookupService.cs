using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class CatalogLookupService(CatalogDbContext db) : ICatalogLookupService
{
    public Task<bool> AddressBelongsToAsync(Guid addressId, Guid customerId,
        CancellationToken ct = default) => db.Addresses.AsNoTracking()
        .AnyAsync(x => x.Id == addressId && x.OwnerUserId == customerId, ct);

    public Task<bool> AddressIsVerifiedForBookingAsync(Guid addressId, Guid customerId,
        CancellationToken ct = default) => db.Addresses.AsNoTracking()
        .AnyAsync(x => x.Id == addressId &&
            x.OwnerUserId == customerId &&
            x.PlaceId != null &&
            x.VerifiedAt != null, ct);

    public Task<bool> ServiceIsActiveAsync(Guid serviceTypeId, CancellationToken ct = default) =>
        db.ServiceTypes.AsNoTracking().AnyAsync(x => x.Id == serviceTypeId && x.IsActive, ct);

    public async Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid addressId,
        CancellationToken ct = default)
    {
        var address = await db.Addresses.AsNoTracking()
            .Where(x => x.Id == addressId)
            .Select(x => new { x.Id, x.FullAddress })
            .SingleOrDefaultAsync(ct);
        return address is null ? null : new AddressDisplaySummary(address.Id, address.FullAddress);
    }

    public async Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid serviceTypeId,
        CancellationToken ct = default)
    {
        var service = await db.ServiceTypes.AsNoTracking()
            .Where(x => x.Id == serviceTypeId && x.IsActive)
            .Select(x => new { x.Id, x.Name, x.Description })
            .SingleOrDefaultAsync(ct);
        return service is null
            ? null
            : new ServiceDisplaySummary(service.Id, service.Name, service.Description);
    }

    public async Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid addressId,
        CancellationToken ct = default)
    {
        var address = await db.Addresses.AsNoTracking()
            .Where(x => x.Id == addressId)
            .Select(x => x.Location)
            .FirstOrDefaultAsync(ct);
        return address is null ? null : (address.Y, address.X);
    }
}
