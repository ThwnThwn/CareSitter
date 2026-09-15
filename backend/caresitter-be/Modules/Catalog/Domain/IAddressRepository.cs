namespace CareSitter.Modules.Catalog.Domain;

public interface IAddressRepository
{
    Task<Address?> GetOwnedAsync(Guid addressId, Guid ownerUserId, CancellationToken ct = default);
    Task<bool> ExistsOwnedAsync(Guid addressId, Guid ownerUserId, CancellationToken ct = default);
    void Add(Address address);
    Task SaveChangesAsync(CancellationToken ct = default);
    Task<bool> TryDeleteAsync(Address address, CancellationToken ct = default);
}
