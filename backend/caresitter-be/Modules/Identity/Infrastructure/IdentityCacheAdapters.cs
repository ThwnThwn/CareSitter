using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class OtpStore(IDistributedCache cache, IdentityDbContext db) : IOtpStore
{
    private sealed record LoginOtpRecord(string Code, Guid? UserId, long RecoveryVersion);
    public async Task<string?> GetAsync(string email, CancellationToken ct = default)
    {
        var stored = await cache.GetStringAsync(OtpKey(email), ct);
        if (stored is null) return null;
        LoginOtpRecord? record;
        try { record = JsonSerializer.Deserialize<LoginOtpRecord>(stored); }
        catch (JsonException) { return null; } // Mã cũ không có phiên bản cần gửi lại.
        if (record?.UserId is not { } id) return null;
        var valid = await db.Users.AsNoTracking().AnyAsync(x => x.Id == id && x.Email == email &&
            x.Status == "ACTIVE" && x.DeletedAt == null && x.RecoveryVersion == record.RecoveryVersion, ct);
        return valid ? record.Code : null;
    }

    public async Task<bool> IsCoolingDownAsync(string email, CancellationToken ct = default) =>
        await cache.GetStringAsync(CooldownKey(email), ct) is not null;

    public async Task SaveAsync(
        string email, string code, TimeSpan ttl, TimeSpan cooldown,
        CancellationToken ct = default)
    {
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Email == email && x.DeletedAt == null, ct);
        var stored = JsonSerializer.Serialize(new LoginOtpRecord(code, user?.Id, user?.RecoveryVersion ?? 0));
        await cache.SetStringAsync(OtpKey(email), stored,
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
