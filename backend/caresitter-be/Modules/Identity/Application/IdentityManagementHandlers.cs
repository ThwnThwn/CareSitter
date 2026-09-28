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

internal sealed class RegisterDeviceCommandHandler(
    IIdentityDeviceStore store, ICurrentUser currentUser)
    : IRequestHandler<RegisterDeviceCommand, Result<DeviceRegistrationResult>>
{
    public async Task<Result<DeviceRegistrationResult>> Handle(
        RegisterDeviceCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var platform = request.Platform?.Trim().ToUpperInvariant() ?? string.Empty;
        var pushToken = string.IsNullOrWhiteSpace(request.PushToken) ? null : request.PushToken.Trim();

        if (pushToken is not null)
        {
            var tokenOwner = await store.FindByPushTokenAsync(pushToken, ct);
            if (tokenOwner is not null && tokenOwner.UserId != userId)
                store.Remove(tokenOwner);
        }

        var existing = await store.FindByUserAndPlatformAsync(userId, platform, ct);
        if (existing is not null)
        {
            existing.UpdatePushToken(pushToken);
            if (request.DeviceName is not null) existing.UpdateDeviceName(request.DeviceName);
            await store.SaveChangesAsync(ct);
            return new DeviceRegistrationResult(ToResponse(existing), false);
        }

        var created = UserDevice.Create(userId, platform);
        if (created.IsFailure) return created.Error;
        created.Value.UpdatePushToken(pushToken);
        if (request.DeviceName is not null) created.Value.UpdateDeviceName(request.DeviceName);
        store.Add(created.Value);
        await store.SaveChangesAsync(ct);
        return new DeviceRegistrationResult(ToResponse(created.Value), true);
    }

    private static DeviceResponse ToResponse(UserDevice device) => new(
        device.Id, device.Platform, device.DeviceName, device.PushToken is not null,
        device.BiometricEnabled, device.LastSeenAt, device.CreatedAt);
}

internal sealed class ListMyDevicesQueryHandler(
    IIdentityDeviceStore store, ICurrentUser currentUser)
    : IRequestHandler<ListMyDevicesQuery, Result<IReadOnlyList<DeviceResponse>>>
{
    public async Task<Result<IReadOnlyList<DeviceResponse>>> Handle(
        ListMyDevicesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        return Result.Success(await store.ListByUserAsync(userId, ct));
    }
}

internal sealed class DeleteDeviceCommandHandler(
    IIdentityDeviceStore store, ICurrentUser currentUser)
    : IRequestHandler<DeleteDeviceCommand, Result>
{
    public async Task<Result> Handle(DeleteDeviceCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var device = await store.FindOwnedAsync(request.DeviceId, userId, ct);
        if (device is null) return Error.NotFound("device.not_found", "Không tìm thấy thiết bị.");
        store.Remove(device);
        await store.SaveChangesAsync(ct);
        return Result.Success();
    }
}

internal sealed class GetProfileQueryHandler(IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<GetProfileQuery, Result<ProfileResponse>>
{
    public async Task<Result<ProfileResponse>> Handle(GetProfileQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        return user is null ? IdentityManagementErrors.UserNotFound() : ToProfile(user);
    }

    internal static ProfileResponse ToProfile(User user) => new(
        user.Id, user.Phone, user.Email, user.FullName!, user.DisplayName!, user.DateOfBirth,
        user.Gender, user.AvatarMediaId, user.AvatarUrl, user.DefaultAddressId, user.Roles);
}

internal sealed class UploadAvatarCommandHandler(
    IIdentityStore store, ICurrentUser currentUser, IMediaService mediaService)
    : IRequestHandler<UploadAvatarCommand, Result<AvatarResponse>>
{
    private static readonly HashSet<string> AllowedTypes =
        new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png", "image/webp" };

    public async Task<Result<AvatarResponse>> Handle(UploadAvatarCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        if (request.Length <= 0)
            return Error.Validation("avatar.empty", "File không được rỗng.");
        if (!AllowedTypes.Contains(request.ContentType))
            return Error.Validation("avatar.invalid_type", "Chỉ chấp nhận định dạng JPEG, PNG hoặc WebP.");
        if (request.Length > 5 * 1024 * 1024)
            return Error.Validation("avatar.too_large", "Ảnh không được vượt quá 5 MB.");

        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        var upload = await mediaService.UploadImageAsync(
            request.Content, request.FileName, "CareSitter/Avatars", ct);
        if (upload.IsFailure) return upload.Error;
        user.SetAvatar(upload.Value);
        await store.SaveChangesAsync(ct);
        return new AvatarResponse(upload.Value);
    }
}

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

internal sealed class ChangePasswordCommandHandler(
    IIdentityStore store,
    ICurrentUser currentUser,
    IPasswordHasher passwordHasher,
    IRefreshTokenSessionService sessions)
    : IRequestHandler<ChangePasswordCommand, Result<string>>
{
    public async Task<Result<string>> Handle(ChangePasswordCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        if (string.IsNullOrWhiteSpace(request.CurrentPassword))
            return Error.Validation("password.current_required", "Vui lòng nhập mật khẩu hiện tại.");
        if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 8)
            return Error.Validation("password.policy", "Mật khẩu mới phải có ít nhất 8 ký tự.");
        if (request.NewPassword == request.CurrentPassword)
            return Error.Validation("password.same", "Mật khẩu mới phải khác mật khẩu hiện tại.");

        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        if (user.PasswordHash is null)
            return Error.Validation("password.no_password",
                "Tài khoản này không dùng đăng nhập bằng mật khẩu.");
        if (!passwordHasher.Verify(request.CurrentPassword, user.PasswordHash))
            return Error.Validation("password.incorrect", "Mật khẩu hiện tại không chính xác.");

        user.SetPassword(passwordHasher.Hash(request.NewPassword));
        await store.SaveChangesAsync(ct);
        await sessions.RevokeAllForUserAsync(userId, ct);
        return "Đổi mật khẩu thành công. Vui lòng đăng nhập lại.";
    }
}

internal sealed class GetNotificationPrefsQueryHandler(IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<GetNotificationPrefsQuery, Result<NotificationPrefs>>
{
    public async Task<Result<NotificationPrefs>> Handle(
        GetNotificationPrefsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        return user is null ? IdentityManagementErrors.UserNotFound()
            : NotificationPrefs.Parse(user.NotificationPrefs);
    }
}

internal sealed class UpdateNotificationPrefsCommandHandler(
    IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<UpdateNotificationPrefsCommand, Result<NotificationPrefs>>
{
    public async Task<Result<NotificationPrefs>> Handle(
        UpdateNotificationPrefsCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        user.SetNotificationPrefs(request.Preferences.ToJson());
        await store.SaveChangesAsync(ct);
        return request.Preferences;
    }
}

internal static class IdentityStoreResponseMapper
{
    internal static AdminUserResponse ToAdminResponse(User user) => new(
        user.Id, user.Email, user.Phone, user.DisplayName, user.FullName, user.AvatarUrl,
        user.Status, user.Roles, user.AdminDepartment, user.AdminRole, user.AdminIsActive,
        user.LastLoginAt, user.CreatedAt, user.UpdatedAt);
}
