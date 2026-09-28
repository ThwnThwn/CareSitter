using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class OtpStore(IDistributedCache cache) : IOtpStore
{
    public Task<string?> GetAsync(string email, CancellationToken ct = default) =>
        cache.GetStringAsync(OtpKey(email), ct);

    public async Task<bool> IsCoolingDownAsync(string email, CancellationToken ct = default) =>
        await cache.GetStringAsync(CooldownKey(email), ct) is not null;

    public async Task SaveAsync(
        string email, string code, TimeSpan ttl, TimeSpan cooldown,
        CancellationToken ct = default)
    {
        await cache.SetStringAsync(OtpKey(email), code,
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = ttl }, ct);
        await cache.SetStringAsync(CooldownKey(email), "1",
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = cooldown }, ct);
    }

    public async Task RemoveAsync(string email, CancellationToken ct = default)
    {
        await cache.RemoveAsync(OtpKey(email), ct);
        await cache.RemoveAsync(CooldownKey(email), ct);
    }

    private static string OtpKey(string email) => $"otp:{email}";
    private static string CooldownKey(string email) => $"otp:cooldown:{email}";
}

internal sealed class AccessTokenRevocationStore(
    IDistributedCache cache,
    ILogger<AccessTokenRevocationStore> logger) : IAccessTokenRevocationStore
{
    public async Task RevokeAsync(
        string tokenId, TimeSpan ttl, CancellationToken ct = default)
    {
        if (ttl <= TimeSpan.Zero) return;
        try
        {
            await cache.SetStringAsync(
                JwtRevocationCacheKeys.RevokedAccessToken(tokenId), "revoked",
                new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = ttl }, ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex,
                "Access-token blacklist cache write failed; durable refresh session is revoked.");
        }
    }
}
