using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class SetAdminUserStatusCommandHandler(
    IIdentityStore store,
    ICurrentUser currentUser,
    IRefreshTokenSessionService sessions,
    IAuditLogger auditLogger)
    : IRequestHandler<SetAdminUserStatusCommand, Result<AdminUserResponse>>
{
    public async Task<Result<AdminUserResponse>> Handle(
        SetAdminUserStatusCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return IdentityManagementErrors.Forbidden();
        if (currentUser.UserId is not { } adminId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(request.UserId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();

        var normalized = request.Status?.Trim().ToUpperInvariant();
        if (user.Id == adminId && normalized != "ACTIVE")
            return Error.Conflict("admin.self_status",
                "Bạn không thể khóa hoặc tạm ngưng chính tài khoản đang đăng nhập.");
        if (user.Roles.Contains("ADMIN") && user.Status == "ACTIVE" && normalized != "ACTIVE" &&
            await store.CountActiveAdminsAsync(ct) <= 1)
            return Error.Conflict("admin.last_active",
                "Hệ thống phải còn ít nhất một tài khoản ADMIN đang hoạt động.");

        var previousStatus = user.Status;
        var result = user.SetStatus(normalized ?? string.Empty);
        if (result.IsFailure) return result.Error;

        await store.SaveChangesAsync(ct);
        if (user.Status != "ACTIVE") await sessions.RevokeAllForUserAsync(user.Id, ct);
        await auditLogger.WriteAsync("ADMIN_USER_STATUS_UPDATED", "User", user.Id,
            new { Status = previousStatus }, new { user.Status }, ct);
        return IdentityStoreResponseMapper.ToAdminResponse(user);
    }
}
