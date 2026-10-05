using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Phản hồi đăng nhập Google, mở rộng LoginResponse với thêm thông tin.
/// </summary>
/// <param name="AccessToken">JWT Access Token.</param>
/// <param name="RefreshToken">Refresh Token.</param>
/// <param name="UserId">ID người dùng.</param>
/// <param name="Roles">Danh sách vai trò.</param>
/// <param name="DisplayName">Tên hiển thị.</param>
/// <param name="IsNewUser">True nếu đây là lần đầu đăng ký qua Google.</param>
public sealed record GoogleLoginResponse(
    string AccessToken,
    string RefreshToken,
    Guid UserId,
    string[] Roles,
    string? DisplayName,
    bool IsNewUser
);
