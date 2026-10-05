using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal static class IdentityManagementErrors
{
    internal static Error Unauthenticated() => Error.Unauthorized(
        "identity.unauthenticated", "Không xác định được người dùng đang đăng nhập.");
    internal static Error Forbidden() => Error.Forbidden(
        "identity.forbidden", "Bạn không có quyền thực hiện thao tác này.");
    internal static Error UserNotFound() => Error.NotFound(
        "profile.user_not_found", "Không tìm thấy tài khoản người dùng.");
}
