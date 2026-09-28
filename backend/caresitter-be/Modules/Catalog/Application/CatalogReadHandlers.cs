using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class ListActiveServicesQueryHandler(
    ICatalogReadStore store,
    IClock clock) : IRequestHandler<ListActiveServicesQuery, IReadOnlyList<ServiceCatalogResponse>>
{
    public Task<IReadOnlyList<ServiceCatalogResponse>> Handle(
        ListActiveServicesQuery request, CancellationToken ct) =>
        store.ListActiveServicesAsync(clock.UtcNow, ct);
}

internal sealed class GetActiveServiceQueryHandler(
    ICatalogReadStore store,
    IClock clock) : IRequestHandler<GetActiveServiceQuery, ServiceCatalogResponse?>
{
    public Task<ServiceCatalogResponse?> Handle(GetActiveServiceQuery request, CancellationToken ct) =>
        store.GetActiveServiceAsync(request.ServiceId, clock.UtcNow, ct);
}

internal sealed class ListOwnedAddressesQueryHandler(
    ICatalogReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListOwnedAddressesQuery, Result<IReadOnlyList<AddressResponse>>>
{
    public async Task<Result<IReadOnlyList<AddressResponse>>> Handle(
        ListOwnedAddressesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return CatalogErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<AddressResponse>>(
            await store.ListOwnedAddressesAsync(userId, ct));
    }
}

internal sealed class GetOwnedAddressQueryHandler(
    ICatalogReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetOwnedAddressQuery, Result<AddressResponse>>
{
    public async Task<Result<AddressResponse>> Handle(GetOwnedAddressQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return CatalogErrors.Unauthenticated();
        var address = await store.GetOwnedAddressAsync(request.AddressId, userId, ct);
        return address is null ? CatalogErrors.AddressNotFound() : address;
    }
}

internal sealed class ListAdminServicesQueryHandler(
    ICatalogReadStore store) : IRequestHandler<ListAdminServicesQuery, IReadOnlyList<AdminServiceResponse>>
{
    public Task<IReadOnlyList<AdminServiceResponse>> Handle(
        ListAdminServicesQuery request, CancellationToken ct) => store.ListAdminServicesAsync(ct);
}
