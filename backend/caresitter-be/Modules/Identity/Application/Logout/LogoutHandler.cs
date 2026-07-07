using CareSitter.Infrastructure.Auth;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Caching.Distributed;

namespace CareSitter.Modules.Identity.Application.Logout;

/// <summary>
/// Stores the current access token jti in Redis until the token expires.
/// </summary>
internal sealed class LogoutHandler : IRequestHandler<LogoutCommand, Result>
{
    private readonly IDistributedCache _cache;

    public LogoutHandler(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<Result> Handle(LogoutCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Jti))
        {
            return Error.Validation("auth.missing_token_id", "Access token khong co ma dinh danh de dang xuat.");
        }

        var now = DateTimeOffset.UtcNow;
        if (request.ExpiresAtUtc <= now)
        {
            return Result.Success();
        }

        var ttl = request.ExpiresAtUtc - now;
        var cacheKey = JwtRevocationCacheKeys.RevokedAccessToken(request.Jti);

        await _cache.SetStringAsync(cacheKey, "revoked", new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = ttl
        }, ct);

        return Result.Success();
    }
}