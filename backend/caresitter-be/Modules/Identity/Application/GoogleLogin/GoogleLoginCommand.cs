using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Yêu cầu đăng nhập / đăng ký tài khoản bằng Google ID Token.
/// </summary>
/// <param name="IdToken">
/// Google ID Token nhận được từ Google Sign-In SDK trên client.
/// Token này được verify phía server bằng Google public keys.
/// </param>
/// <param name="Roles">
/// Vai trò muốn đăng ký (chỉ cần khi tạo tài khoản mới qua Google lần đầu).
/// Nếu null hoặc rỗng và chưa có tài khoản → mặc định là ["CUSTOMER"].
/// </param>
/// <param name="RequiredRole">Vai trò bắt buộc cho ứng dụng đang đăng nhập, ví dụ CUSTOMER hoặc CAREGIVER.</param>
public sealed record GoogleLoginCommand(
    string IdToken,
    string[]? Roles = null,
    string? RequiredRole = null
) : IRequest<Result<GoogleLoginResponse>>;

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
