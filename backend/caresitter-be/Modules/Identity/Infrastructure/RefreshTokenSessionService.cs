using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Text.Json;

namespace CareSitter.Modules.Identity.Infrastructure;

/// <summary>
/// PostgreSQL is authoritative for refresh sessions. Redis contains only an
/// optional lookup cache and may be unavailable or empty without invalidating sessions.
/// </summary>
internal sealed class RefreshTokenSessionService(
    IdentityDbContext db,
    IDistributedCache cache,
    IJwtTokenService jwtTokenService,
    IOptions<JwtSettings> jwtSettings,
    IHttpContextAccessor httpContextAccessor,
    ILogger<RefreshTokenSessionService> logger) : IRefreshTokenSessionService
{
    private const string SessionCachePrefix = "session:";
    private readonly TimeSpan _lifetime =
        TimeSpan.FromDays(jwtSettings.Value.RefreshTokenExpiryDays);

    public async Task<IssuedTokenPair> IssueAsync(
        User user,
        CancellationToken ct,
        string? deviceId = null,
        string? deviceInfo = null,
        string? ipAddress = null)
    {
        deviceId ??= CurrentHeader("X-Device-Id");
        deviceInfo ??= CurrentHeader("User-Agent");
        ipAddress ??= httpContextAccessor.HttpContext?.Connection.RemoteIpAddress?.ToString();
        var now = DateTimeOffset.UtcNow;
        var rawRefreshToken = jwtTokenService.GenerateRefreshToken();
        var session = RefreshTokenSession.Create(
            user.Id,
            jwtTokenService.HashRefreshToken(rawRefreshToken),
            now,
            now.Add(_lifetime),
            deviceId,
            deviceInfo,
            ipAddress);

        db.RefreshTokenSessions.Add(session);
        await db.SaveChangesAsync(ct); // DB first: cache failure must not lose the session.
        await TrySetCacheAsync(session, ct);

        return new IssuedTokenPair(
            jwtTokenService.GenerateAccessToken(user.Id, user.Roles, user.DisplayName, session.Id),
            rawRefreshToken);
    }

    public async Task<Result<IssuedTokenPair>> RotateAsync(
        string rawRefreshToken,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(rawRefreshToken))
            return Error.Validation("auth.refresh_token_required", "Refresh token là bắt buộc.");

        var tokenHash = jwtTokenService.HashRefreshToken(rawRefreshToken);
        var cacheKey = JwtRevocationCacheKeys.RefreshToken(tokenHash);
        var session = await FindSessionAsync(tokenHash, cacheKey, ct);
        var now = DateTimeOffset.UtcNow;

        if (session is null)
        {
            await TryRemoveCacheAsync(cacheKey, ct);
            return Error.Validation("auth.invalid_refresh_token",
                "Refresh token không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.");
        }

        if (session.RevokedAt is not null)
            return await HandleReuseDetectedAsync(session, "revoked_token_reused", cacheKey, ct);

        if (session.ExpiresAt <= now)
        {
            await TryRemoveCacheAsync(cacheKey, ct);
            return Error.Validation("auth.invalid_refresh_token",
                "Refresh token không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.");
        }

        var user = await db.Users.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == session.UserId, ct);
        if (user is null)
            return Error.NotFound("auth.user_not_found", "Tài khoản không tồn tại.");
        if (user.Status != "ACTIVE")
            return Error.Validation("auth.inactive_user",
                $"Tài khoản đang ở trạng thái {user.Status}.");

        var newRawToken = jwtTokenService.GenerateRefreshToken();
        var newSession = RefreshTokenSession.Create(
            user.Id,
            jwtTokenService.HashRefreshToken(newRawToken),
            now,
            now.Add(_lifetime),
            session.DeviceId,
            CurrentHeader("User-Agent") ?? session.DeviceInfo,
            httpContextAccessor.HttpContext?.Connection.RemoteIpAddress?.ToString() ?? session.IpAddress);

        int revoked;
        await using (var transaction = await db.Database.BeginTransactionAsync(ct))
        {
            db.RefreshTokenSessions.Add(newSession);
            await db.SaveChangesAsync(ct);

            revoked = await db.RefreshTokenSessions
                .Where(x => x.Id == session.Id && x.RevokedAt == null && x.ExpiresAt > now)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(x => x.RevokedAt, now)
                    .SetProperty(x => x.ReplacedById, newSession.Id), ct);

            if (revoked == 1)
                await transaction.CommitAsync(ct);
            else
                await transaction.RollbackAsync(ct);
        }

        if (revoked != 1)
        {
            db.ChangeTracker.Clear();
            return await HandleReuseDetectedAsync(
                session, "concurrent_refresh_claim_lost", cacheKey, ct);
        }

        await TryRemoveCacheAsync(cacheKey, ct);
        await TrySetCacheAsync(newSession, ct);

        return new IssuedTokenPair(
            jwtTokenService.GenerateAccessToken(user.Id, user.Roles, user.DisplayName, newSession.Id),
            newRawToken);
    }

    public async Task RevokeAsync(string rawRefreshToken, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(rawRefreshToken)) return;
        var hash = jwtTokenService.HashRefreshToken(rawRefreshToken);
        var now = DateTimeOffset.UtcNow;

        await db.RefreshTokenSessions
            .Where(x => x.TokenHash == hash && x.RevokedAt == null)
            .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.RevokedAt, now), ct);
        await TryRemoveCacheAsync(JwtRevocationCacheKeys.RefreshToken(hash), ct);
    }

    public async Task RevokeSessionAsync(Guid userId, Guid sessionId, CancellationToken ct)
    {
        var session = await db.RefreshTokenSessions.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == sessionId && x.UserId == userId, ct);
        if (session is null) return;

        await db.RefreshTokenSessions
            .Where(x => x.Id == sessionId && x.UserId == userId && x.RevokedAt == null)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.RevokedAt, DateTimeOffset.UtcNow), ct);
        await TryRemoveCacheAsync(
            JwtRevocationCacheKeys.RefreshToken(session.TokenHash), ct);
    }

    public async Task RevokeAllForUserAsync(Guid userId, CancellationToken ct)
    {
        var activeHashes = await db.RefreshTokenSessions
            .Where(x => x.UserId == userId && x.RevokedAt == null)
            .Select(x => x.TokenHash)
            .ToListAsync(ct);
        if (activeHashes.Count == 0) return;

        var now = DateTimeOffset.UtcNow;
        await db.RefreshTokenSessions
            .Where(x => x.UserId == userId && x.RevokedAt == null)
            .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.RevokedAt, now), ct);

        foreach (var hash in activeHashes)
            await TryRemoveCacheAsync(JwtRevocationCacheKeys.RefreshToken(hash), ct);
    }

    private async Task<Result<IssuedTokenPair>> HandleReuseDetectedAsync(
        RefreshTokenSession compromisedSession,
        string reason,
        string compromisedCacheKey,
        CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        List<string> sessionHashes;

        await using (var transaction = await db.Database.BeginTransactionAsync(ct))
        {
            await db.RefreshTokenSessions
                .Where(x => x.UserId == compromisedSession.UserId && x.RevokedAt == null)
                .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.RevokedAt, now), ct);

            sessionHashes = await db.RefreshTokenSessions
                .Where(x => x.UserId == compromisedSession.UserId)
                .Select(x => x.TokenHash)
                .ToListAsync(ct);

            var audit = AuditLog.Create(
                "REFRESH_TOKEN_REUSE_DETECTED",
                "REFRESH_TOKEN_SESSION",
                actorUserId: compromisedSession.UserId,
                entityId: compromisedSession.Id,
                afterData: JsonSerializer.Serialize(new { reason, detectedAt = now }),
                ipAddress: httpContextAccessor.HttpContext?.Connection.RemoteIpAddress?.ToString(),
                userAgent: CurrentHeader("User-Agent"));
            if (audit.IsSuccess)
            {
                db.AuditLogs.Add(audit.Value);
                await db.SaveChangesAsync(ct);
            }

            await transaction.CommitAsync(ct);
        }

        await TryRemoveCacheAsync(compromisedCacheKey, ct);
        foreach (var hash in sessionHashes)
            await TryRemoveCacheAsync(JwtRevocationCacheKeys.RefreshToken(hash), ct);

        logger.LogWarning(
            "Refresh-token reuse detected for user {UserId}, session {SessionId}, reason {Reason}. All active sessions were revoked.",
            compromisedSession.UserId,
            compromisedSession.Id,
            reason);

        return Error.Validation(
            "auth.refresh_token_reuse_detected",
            "Phát hiện refresh token đã được sử dụng lại. Tất cả phiên đăng nhập đã bị thu hồi.");
    }

    private async Task<RefreshTokenSession?> FindSessionAsync(
        string tokenHash,
        string cacheKey,
        CancellationToken ct)
    {
        var cachedSessionId = await TryGetCacheAsync(cacheKey, ct);
        if (cachedSessionId?.StartsWith(SessionCachePrefix, StringComparison.Ordinal) == true &&
            Guid.TryParse(cachedSessionId[SessionCachePrefix.Length..], out var sessionId))
        {
            var cached = await db.RefreshTokenSessions.AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == sessionId && x.TokenHash == tokenHash, ct);
            if (cached is not null) return cached;
        }

        var session = await db.RefreshTokenSessions.AsNoTracking()
            .SingleOrDefaultAsync(x => x.TokenHash == tokenHash, ct);

        // Rolling-deploy compatibility: the previous implementation cached a
        // plain userId. Import that still-valid legacy session into PostgreSQL
        // on its first refresh, then all later rotations use durable records.
        if (session is null && Guid.TryParse(cachedSessionId, out var legacyUserId))
        {
            var userExists = await db.Users.AsNoTracking()
                .AnyAsync(x => x.Id == legacyUserId && x.Status == "ACTIVE", ct);
            if (userExists)
            {
                var now = DateTimeOffset.UtcNow;
                var imported = RefreshTokenSession.Create(
                    legacyUserId, tokenHash, now, now.Add(_lifetime));
                db.RefreshTokenSessions.Add(imported);
                try
                {
                    await db.SaveChangesAsync(ct);
                    session = imported;
                    logger.LogInformation(
                        "Imported a legacy Redis refresh session into PostgreSQL.");
                }
                catch (DbUpdateException)
                {
                    db.Entry(imported).State = EntityState.Detached;
                    session = await db.RefreshTokenSessions.AsNoTracking()
                        .SingleOrDefaultAsync(x => x.TokenHash == tokenHash, ct);
                }
            }
        }

        if (session is not null && session.IsActiveAt(DateTimeOffset.UtcNow))
            await TrySetCacheAsync(session, ct); // warm cache after Redis restart/eviction.
        return session;
    }

    private async Task<string?> TryGetCacheAsync(string key, CancellationToken ct)
    {
        try { return await cache.GetStringAsync(key, ct); }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Refresh-token cache read failed; falling back to PostgreSQL.");
            return null;
        }
    }

    private string? CurrentHeader(string name)
    {
        var value = httpContextAccessor.HttpContext?.Request.Headers[name].ToString();
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private async Task TrySetCacheAsync(RefreshTokenSession session, CancellationToken ct)
    {
        var ttl = session.ExpiresAt - DateTimeOffset.UtcNow;
        if (ttl <= TimeSpan.Zero) return;
        try
        {
            await cache.SetStringAsync(
                JwtRevocationCacheKeys.RefreshToken(session.TokenHash),
                SessionCachePrefix + session.Id,
                new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = ttl },
                ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Refresh-token cache write failed; PostgreSQL remains authoritative.");
        }
    }

    private async Task TryRemoveCacheAsync(string key, CancellationToken ct)
    {
        try { await cache.RemoveAsync(key, ct); }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Refresh-token cache eviction failed; DB validation still prevents reuse.");
        }
    }
}
