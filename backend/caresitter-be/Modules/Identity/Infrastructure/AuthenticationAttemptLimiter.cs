using System.Security.Cryptography;
using System.Text;
using CareSitter.Modules.Identity.Application;
using Microsoft.Extensions.Caching.Distributed;

namespace CareSitter.Modules.Identity.Infrastructure;

/// <summary>
/// Per-identifier protection layered on top of the HTTP per-IP rate limiter.
/// Cache keys contain only a SHA-256 digest, never an email or phone number.
/// </summary>
internal sealed class AuthenticationAttemptLimiter(IDistributedCache cache)
    : IAuthenticationAttemptLimiter
{
    public async Task<bool> IsBlockedAsync(
        string scope,
        string subject,
        CancellationToken ct)
    {
        return await cache.GetStringAsync(Key(scope, subject, "blocked"), ct) is not null;
    }

    public async Task<bool> RecordFailureAsync(
        string scope,
        string subject,
        int maxAttempts,
        TimeSpan window,
        TimeSpan blockDuration,
        CancellationToken ct)
    {
        var attemptsKey = Key(scope, subject, "attempts");
        var value = await cache.GetStringAsync(attemptsKey, ct);
        var attempts = int.TryParse(value, out var parsed) ? parsed + 1 : 1;

        await cache.SetStringAsync(attemptsKey, attempts.ToString(),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = window }, ct);

        if (attempts < maxAttempts) return false;

        await cache.SetStringAsync(Key(scope, subject, "blocked"), "1",
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = blockDuration }, ct);
        return true;
    }

    public async Task<bool> TryConsumeAsync(
        string scope,
        string subject,
        int limit,
        TimeSpan window,
        CancellationToken ct)
    {
        var key = Key(scope, subject, "window");
        var value = await cache.GetStringAsync(key, ct);
        var count = int.TryParse(value, out var parsed) ? parsed : 0;
        if (count >= limit) return false;

        await cache.SetStringAsync(key, (count + 1).ToString(),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = window }, ct);
        return true;
    }

    public async Task ResetAsync(string scope, string subject, CancellationToken ct)
    {
        await cache.RemoveAsync(Key(scope, subject, "attempts"), ct);
        await cache.RemoveAsync(Key(scope, subject, "blocked"), ct);
    }

    private static string Key(string scope, string subject, string suffix)
    {
        var normalized = subject.Trim().ToLowerInvariant();
        var digest = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalized)))
            .ToLowerInvariant();
        return $"auth:{scope}:{digest}:{suffix}";
    }
}
