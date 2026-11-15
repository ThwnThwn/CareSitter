using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class SetAdminUserRolesCommandHandler(
    IIdentityStore store,
    ICurrentUser currentUser,
    IRefreshTokenSessionService sessions,
    IAuditLogger auditLogger)
    : IRequestHandler<SetAdminUserRolesCommand, Result<AdminUserResponse>>
{
    private static readonly string[] AllowedRoles = ["CUSTOMER", "CAREGIVER", "ADMIN"];

    public async Task<Result<AdminUserResponse>> Handle(
        SetAdminUserRolesCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return IdentityManagementErrors.Forbidden();
        if (currentUser.UserId is not { } adminId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(request.UserId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();

        var roles = (request.Roles ?? [])
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim().ToUpperInvariant()).Distinct().ToArray();
        if (roles.Length == 0 || roles.Any(x => !AllowedRoles.Contains(x)))
            return Error.Validation("admin.invalid_roles",
                "Vai trò phải gồm CUSTOMER, CAREGIVER hoặc ADMIN.");
        if (user.Id == adminId && !roles.Contains("ADMIN"))
            return Error.Conflict("admin.self_role",
                "Bạn không thể tự gỡ quyền ADMIN của tài khoản đang đăng nhập.");
        if (user.Roles.Contains("ADMIN") && !roles.Contains("ADMIN") && user.Status == "ACTIVE" &&
            await store.CountActiveAdminsAsync(ct) <= 1)
            return Error.Conflict("admin.last_active",
                "Hệ thống phải còn ít nhất một tài khoản ADMIN đang hoạt động.");

        var previousRoles = user.Roles.ToArray();
        user.SetRoles(roles);
        await store.SaveChangesAsync(ct);
        await sessions.RevokeAllForUserAsync(user.Id, ct);
        await auditLogger.WriteAsync("ADMIN_USER_ROLES_UPDATED", "User", user.Id,
            new { Roles = previousRoles }, new { user.Roles }, ct);
        return IdentityStoreResponseMapper.ToAdminResponse(user);
    }
}
