using System.Security.Claims;

namespace CareSitter.Infrastructure.Auth;

/// <summary>
/// Giao diện định nghĩa các thao tác tạo và kiểm tra JWT Token.
/// </summary>
public interface IJwtTokenService
{
    /// <summary>
    /// Tạo Access Token (JWT) chứa thông tin của người dùng.
    /// </summary>
    /// <param name="userId">ID của người dùng.</param>
    /// <param name="roles">Danh sách các vai trò (roles) của người dùng.</param>
    /// <param name="displayName">Tên hiển thị (tùy chọn).</param>
    /// <returns>Chuỗi JWT Access Token.</returns>
    string GenerateAccessToken(Guid userId, IEnumerable<string> roles, string? displayName = null);

    /// <summary>
    /// Tạo Refresh Token ngẫu nhiên dưới dạng mã hóa Base64 bảo mật.
    /// </summary>
    /// <returns>Chuỗi Refresh Token.</returns>
    string GenerateRefreshToken();

    /// <summary>
    /// Giải mã và kiểm tra một JWT Access Token (bao gồm cả trường hợp đã hết hạn)
    /// để lấy thông tin Claims phục vụ cho luồng làm mới (Refresh Token).
    /// </summary>
    /// <param name="token">Access Token cần giải mã.</param>
    /// <returns>ClaimsPrincipal chứa các claims nếu hợp lệ, ngược lại là null.</returns>
    ClaimsPrincipal? GetPrincipalFromExpiredToken(string token);

    /// <summary>
    /// Hash raw refresh token bằng SHA-256 để dùng làm Redis key.
    /// Đảm bảo raw token không bị lộ nếu Redis bị xâm phạm.
    /// </summary>
    /// <param name="rawToken">Refresh token gốc (opaque string).</param>
    /// <returns>Chuỗi hex SHA-256 của token.</returns>
    string HashRefreshToken(string rawToken);
}
