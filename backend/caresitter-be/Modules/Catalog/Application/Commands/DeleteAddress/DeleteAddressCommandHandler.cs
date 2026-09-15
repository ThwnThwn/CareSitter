using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.DeleteAddress;

internal sealed class DeleteAddressCommandHandler(
    IAddressRepository repository,
    ICurrentUser currentUser) : IRequestHandler<DeleteAddressCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(DeleteAddressCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return CatalogErrors.Unauthenticated();
        var entity = await repository.GetOwnedAsync(request.AddressId, userId, ct);
        if (entity is null) return CatalogErrors.AddressNotFound();
        if (!await repository.TryDeleteAsync(entity, ct))
            return CatalogErrors.AddressInUse();
        return Unit.Value;
    }
}
