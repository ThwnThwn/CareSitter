/// <summary>
/// Redis key conventions used for JWT revocation and refresh token storage.
/// </summary>
public static class JwtRevocationCacheKeys
{
    private const string RevokedAccessTokenPrefix = "jwt:blacklist:";
    private const string RefreshTokenPrefix        = "refresh:";

    /// <summary>Key lưu blacklist access token (theo JTI).</summary>
    public static string RevokedAccessToken(string jti) => RevokedAccessTokenPrefix + jti;

    /// <summary>
    /// Key lưu refresh token trong Redis.
    /// rawToken được hash SHA-256 trước khi làm key để đảm bảo token gốc không bị lộ nếu Redis bị xem.
    /// Dùng <see cref="IJwtTokenService.HashRefreshToken"/> để hash trước khi gọi hàm này.
    /// </summary>
    public static string RefreshToken(string hashedToken) => RefreshTokenPrefix + hashedToken;
}
