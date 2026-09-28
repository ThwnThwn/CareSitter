using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Request body công khai cho đăng nhập Google. Client chỉ được gửi ID token;
/// role được endpoint phía server quyết định theo ứng dụng.
/// </summary>
/// <param name="IdToken">
/// Google ID Token nhận được từ Google Sign-In SDK trên client.
/// Token này được verify phía server bằng Google public keys.
/// </param>
public sealed record GoogleLoginRequest(string IdToken);

/// <summary>
/// Command nội bộ. RequiredRole luôn do controller gán cứng, không bind từ request body.
/// </summary>
public sealed record GoogleLoginCommand(
    string IdToken,
    string RequiredRole
) : IRequest<Result<GoogleLoginResponse>>;

internal static class GoogleLoginRolePolicy
{
    public const string Customer = "CUSTOMER";
    public const string Caregiver = "CAREGIVER";

    public static Result<string> Validate(string? requiredRole)
    {
        var normalized = requiredRole?.Trim().ToUpperInvariant();
        return normalized is Customer or Caregiver
            ? Result.Success(normalized)
            : Error.Forbidden(
                "auth.google_role_not_allowed",
                "Google self-registration chỉ hỗ trợ Customer hoặc Caregiver.");
    }
}

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
