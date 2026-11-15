using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application.Login;

/// <summary>
/// Phản hồi kết quả đăng nhập chứa thông tin tokens và người dùng.
/// </summary>
/// <param name="AccessToken">JWT Access Token dùng trong Authorization header của các request sau.</param>
/// <param name="RefreshToken">Refresh Token dùng để cấp lại Access Token mới.</param>
/// <param name="UserId">ID của người dùng đăng nhập.</param>
/// <param name="Roles">Danh sách vai trò (CUSTOMER, CAREGIVER, ADMIN) của người dùng.</param>
/// <param name="DisplayName">Tên hiển thị của người dùng.</param>
public sealed record LoginResponse(
    string AccessToken,
    string RefreshToken,
    Guid UserId,
    string[] Roles,
    string? DisplayName
);
