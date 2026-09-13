using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application.AuthSessions;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Identity.Application.Logout;

/// <summary>
/// Revokes the durable refresh session and best-effort blacklists the current
/// short-lived access token in Redis.
/// </summary>
public sealed class LogoutHandler(
    IDistributedCache cache,
    RefreshTokenSessionService sessions,
    ILogger<LogoutHandler> logger) : IRequestHandler<LogoutCommand, Result>
{
    public async Task<Result> Handle(LogoutCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Jti))
            return Error.Validation("auth.missing_token", "Access token không hợp lệ.");

        // PostgreSQL first: Redis restart/failure cannot restore this session.
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
            await sessions.RevokeAsync(request.RefreshToken, ct);

        var now = DateTimeOffset.UtcNow;
        if (request.ExpiresAtUtc > now)
        {
            try
            {
                await cache.SetStringAsync(
                    JwtRevocationCacheKeys.RevokedAccessToken(request.Jti),
                    "revoked",
                    new DistributedCacheEntryOptions
                    {
                        AbsoluteExpirationRelativeToNow = request.ExpiresAtUtc - now
                    }, ct);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex,
                    "Access-token blacklist cache write failed; durable refresh session is revoked.");
            }
        }

        return Result.Success();
    }
}
