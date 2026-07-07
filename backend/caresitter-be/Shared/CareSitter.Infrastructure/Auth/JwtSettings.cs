namespace CareSitter.Infrastructure.Auth;

/// <summary>
/// Cấu hình JWT Settings dùng cho Authentication.
/// Được map từ configuration section "Jwt" trong appsettings.json.
/// </summary>
public sealed class JwtSettings
{
    public const string SectionName = "Jwt";

    /// <summary>
    /// Nhà phát hành Token (Issuer).
    /// </summary>
    public string Issuer { get; init; } = string.Empty;

    /// <summary>
    /// Đối tượng sử dụng Token (Audience).
    /// </summary>
    public string Audience { get; init; } = string.Empty;

    /// <summary>
    /// Khóa bí mật dùng để ký Token (SecretKey). Yêu cầu độ dài tối thiểu 32 ký tự (256-bit).
    /// </summary>
    public string SecretKey { get; init; } = string.Empty;

    /// <summary>
    /// Thời gian sống của Access Token tính bằng phút. Mặc định là 15 phút.
    /// </summary>
    public int ExpiryMinutes { get; init; } = 15;

    /// <summary>
    /// Thời gian sống của Refresh Token tính bằng ngày. Mặc định là 7 ngày.
    /// </summary>
    public int RefreshTokenExpiryDays { get; init; } = 7;
}
