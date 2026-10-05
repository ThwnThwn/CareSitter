using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class SetDefaultAddressCommandHandler(IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<SetDefaultAddressCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(SetDefaultAddressCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        user.SetDefaultAddress(request.AddressId);
        await store.SaveChangesAsync(ct);
        return request.AddressId;
    }
}
