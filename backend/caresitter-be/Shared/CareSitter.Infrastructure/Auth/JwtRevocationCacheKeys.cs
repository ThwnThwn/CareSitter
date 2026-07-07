namespace CareSitter.Infrastructure.Auth;

/// <summary>
/// Redis key conventions used for JWT revocation checks.
/// </summary>
public static class JwtRevocationCacheKeys
{
    private const string RevokedAccessTokenPrefix = "jwt:blacklist:";

    public static string RevokedAccessToken(string jti) => RevokedAccessTokenPrefix + jti;
}
