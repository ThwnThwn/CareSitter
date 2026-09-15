using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.SetDefaultAddress;

internal sealed class SetDefaultAddressCommandHandler(
    IAddressRepository repository,
    ICurrentUser currentUser) : IRequestHandler<SetDefaultAddressCommand, Result<DefaultAddressResponse>>
{
    public async Task<Result<DefaultAddressResponse>> Handle(
        SetDefaultAddressCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return CatalogErrors.Unauthenticated();
        var exists = await repository.ExistsOwnedAsync(request.AddressId, userId, ct);
        if (!exists) return CatalogErrors.AddressNotFound();
        return new DefaultAddressResponse(request.AddressId, true);
    }
}
