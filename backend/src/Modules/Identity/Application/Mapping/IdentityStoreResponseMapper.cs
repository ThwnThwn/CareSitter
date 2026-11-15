using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal static class IdentityStoreResponseMapper
{
    internal static AdminUserResponse ToAdminResponse(User user) => new(
        user.Id, user.Email, user.Phone, user.DisplayName, user.FullName, user.AvatarUrl,
        user.Status, user.Roles, user.AdminDepartment, user.AdminRole, user.AdminIsActive,
        user.LastLoginAt, user.CreatedAt, user.UpdatedAt);
}
