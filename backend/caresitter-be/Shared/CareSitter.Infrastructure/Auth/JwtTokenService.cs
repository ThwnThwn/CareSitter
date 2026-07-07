using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace CareSitter.Infrastructure.Auth;

/// <summary>
/// Lớp triển khai các phương thức xử lý JWT Token (Access Token và Refresh Token).
/// </summary>
public sealed class JwtTokenService : IJwtTokenService
{
    private readonly JwtSettings _jwtSettings;

    /// <summary>
    /// Khởi tạo JwtTokenService với cấu hình từ appsettings.
    /// </summary>
    /// <param name="jwtSettings">Cấu hình JWT được tiêm (inject) qua IOptions.</param>
    public JwtTokenService(IOptions<JwtSettings> jwtSettings)
    {
        _jwtSettings = jwtSettings.Value;
    }

    /// <summary>
    /// Tạo Access Token (JWT) chứa thông tin của người dùng.
    /// </summary>
    /// <param name="userId">ID của người dùng.</param>
    /// <param name="roles">Danh sách các vai trò (roles) của người dùng.</param>
    /// <param name="displayName">Tên hiển thị (tùy chọn).</param>
    /// <returns>Chuỗi JWT Access Token đã ký.</returns>
    public string GenerateAccessToken(Guid userId, IEnumerable<string> roles, string? displayName = null)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        if (!string.IsNullOrWhiteSpace(displayName))
        {
            claims.Add(new(ClaimTypes.Name, displayName));
        }

        // Thêm các role vào claims để kiểm tra phân quyền sau này
        foreach (var role in roles)
        {
            claims.Add(new(ClaimTypes.Role, role));
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSettings.SecretKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwtSettings.Issuer,
            audience: _jwtSettings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_jwtSettings.ExpiryMinutes),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>
    /// Tạo Refresh Token ngẫu nhiên dưới dạng mã hóa Base64 bảo mật.
    /// </summary>
    /// <returns>Chuỗi Refresh Token.</returns>
    public string GenerateRefreshToken()
    {
        var randomNumber = new byte[32];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomNumber);
        return Convert.ToBase64String(randomNumber);
    }

    /// <summary>
    /// Giải mã và kiểm tra một JWT Access Token (bao gồm cả trường hợp đã hết hạn)
    /// để lấy thông tin Claims phục vụ cho luồng làm mới (Refresh Token).
    /// </summary>
    /// <param name="token">Access Token cần giải mã.</param>
    /// <returns>ClaimsPrincipal chứa các claims nếu hợp lệ, ngược lại là null.</returns>
    public ClaimsPrincipal? GetPrincipalFromExpiredToken(string token)
    {
        var tokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = _jwtSettings.Audience,
            ValidateIssuer = true,
            ValidIssuer = _jwtSettings.Issuer,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSettings.SecretKey)),
            ValidateLifetime = false // Không kiểm tra hết hạn để lấy được claims của token cũ
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        try
        {
            var principal = tokenHandler.ValidateToken(token, tokenValidationParameters, out var securityToken);
            
            // Đảm bảo thuật toán ký là HmacSha256 tránh lỗ hổng thuật toán "none"
            if (securityToken is not JwtSecurityToken jwtSecurityToken ||
                !jwtSecurityToken.Header.Alg.Equals(SecurityAlgorithms.HmacSha256, StringComparison.InvariantCultureIgnoreCase))
            {
                return null;
            }

            return principal;
        }
        catch
        {
            return null;
        }
    }
}
