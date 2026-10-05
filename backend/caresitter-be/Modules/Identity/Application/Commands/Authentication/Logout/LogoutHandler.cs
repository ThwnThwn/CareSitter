using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Logout;

/// <summary>
/// Revokes the durable refresh session and best-effort blacklists the current
/// short-lived access token in Redis.
/// </summary>
public sealed class LogoutHandler(
    IAccessTokenRevocationStore accessTokens,
    IRefreshTokenSessionService sessions,
    IClock clock) : IRequestHandler<LogoutCommand, Result>
{
    public async Task<Result> Handle(LogoutCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Jti))
            return Error.Validation("auth.missing_token", "Access token không hợp lệ.");

        // PostgreSQL first: Redis restart/failure cannot restore this session.
        await sessions.RevokeSessionAsync(request.UserId, request.SessionId, ct);
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
            await sessions.RevokeAsync(request.RefreshToken, ct);

        var now = clock.UtcNow;
        if (request.ExpiresAtUtc > now)
            await accessTokens.RevokeAsync(request.Jti, request.ExpiresAtUtc - now, ct);

        return Result.Success();
    }
}
