using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public interface ICatalogReadStore
{
    Task<IReadOnlyList<ServiceCatalogResponse>> ListActiveServicesAsync(
        DateTimeOffset now, CancellationToken ct = default);

    Task<ServiceCatalogResponse?> GetActiveServiceAsync(
        Guid serviceId, DateTimeOffset now, CancellationToken ct = default);

    Task<IReadOnlyList<AddressResponse>> ListOwnedAddressesAsync(
        Guid ownerUserId, CancellationToken ct = default);

    Task<AddressResponse?> GetOwnedAddressAsync(
        Guid addressId, Guid ownerUserId, CancellationToken ct = default);

    Task<IReadOnlyList<AdminServiceResponse>> ListAdminServicesAsync(
        CancellationToken ct = default);

    Task<AdminServiceResponse?> GetAdminServiceAsync(
        Guid serviceId, CancellationToken ct = default);
}
