using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

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
