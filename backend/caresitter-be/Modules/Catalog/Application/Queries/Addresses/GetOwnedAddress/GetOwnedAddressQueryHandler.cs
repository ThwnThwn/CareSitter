using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

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
