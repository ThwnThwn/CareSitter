using CareSitter.Modules.Catalog.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class AddressRepository(CatalogDbContext db) : IAddressRepository
{
    public Task<Address?> GetOwnedAsync(Guid addressId, Guid ownerUserId, CancellationToken ct = default) =>
        db.Addresses.SingleOrDefaultAsync(x =>
            x.Id == addressId && x.OwnerUserId == ownerUserId, ct);

    public Task<bool> ExistsOwnedAsync(Guid addressId, Guid ownerUserId, CancellationToken ct = default) =>
        db.Addresses.AsNoTracking().AnyAsync(x =>
            x.Id == addressId && x.OwnerUserId == ownerUserId, ct);

    public void Add(Address address) => db.Addresses.Add(address);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);

    public async Task<bool> TryDeleteAsync(Address address, CancellationToken ct = default)
    {
        db.Addresses.Remove(address);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException)
        {
            // Preserve the legacy controller behavior: every update failure maps to the same 409.
            return false;
        }
    }
}
