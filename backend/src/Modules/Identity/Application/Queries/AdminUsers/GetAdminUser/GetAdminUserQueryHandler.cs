using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class GetAdminUserQueryHandler(
    IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<GetAdminUserQuery, Result<AdminUserResponse>>
{
    public async Task<Result<AdminUserResponse>> Handle(GetAdminUserQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return IdentityManagementErrors.Forbidden();
        var user = await store.GetUserResponseAsync(request.UserId, ct);
        return user is null ? IdentityManagementErrors.UserNotFound() : user;
    }
}
