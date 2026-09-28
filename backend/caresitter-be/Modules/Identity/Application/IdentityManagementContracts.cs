using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record ListAdminUsersQuery(
    string? Query, string? Role, string? Status, int Page, int PageSize)
    : IRequest<Result<IdentityPage<AdminUserResponse>>>;
public sealed record GetAdminUserQuery(Guid UserId) : IRequest<Result<AdminUserResponse>>;
public sealed record SetAdminUserStatusCommand(Guid UserId, string Status)
    : IRequest<Result<AdminUserResponse>>;
public sealed record SetAdminUserRolesCommand(Guid UserId, string[]? Roles)
    : IRequest<Result<AdminUserResponse>>;

public sealed record RegisterDeviceCommand(
    string Platform, string? PushToken = null, string? DeviceName = null)
    : IRequest<Result<DeviceRegistrationResult>>;
public sealed record DeviceRegistrationResult(DeviceResponse Device, bool Created);
public sealed record ListMyDevicesQuery : IRequest<Result<IReadOnlyList<DeviceResponse>>>;
public sealed record DeleteDeviceCommand(Guid DeviceId) : IRequest<Result>;

public sealed record GetProfileQuery : IRequest<Result<UpdateProfile.ProfileResponse>>;
public sealed record UploadAvatarCommand(
    Stream Content, string FileName, string ContentType, long Length)
    : IRequest<Result<AvatarResponse>>;
public sealed record SetDefaultAddressCommand(Guid AddressId) : IRequest<Result<Guid>>;
public sealed record ChangePasswordCommand(string CurrentPassword, string NewPassword)
    : IRequest<Result<string>>;
public sealed record GetNotificationPrefsQuery : IRequest<Result<NotificationPrefs>>;
public sealed record UpdateNotificationPrefsCommand(NotificationPrefs Preferences)
    : IRequest<Result<NotificationPrefs>>;

internal static class IdentityManagementErrors
{
    internal static Error Unauthenticated() => Error.Unauthorized(
        "identity.unauthenticated", "Không xác định được người dùng đang đăng nhập.");
    internal static Error Forbidden() => Error.Forbidden(
        "identity.forbidden", "Bạn không có quyền thực hiện thao tác này.");
    internal static Error UserNotFound() => Error.NotFound(
        "profile.user_not_found", "Không tìm thấy tài khoản người dùng.");
}
