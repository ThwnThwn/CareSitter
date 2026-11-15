using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class ListAdminUsersQueryHandler(
    IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<ListAdminUsersQuery, Result<IdentityPage<AdminUserResponse>>>
{
    public async Task<Result<IdentityPage<AdminUserResponse>>> Handle(
        ListAdminUsersQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return IdentityManagementErrors.Forbidden();
        return await store.ListUsersAsync(request.Query, request.Role, request.Status,
            Math.Max(request.Page, 1), Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
