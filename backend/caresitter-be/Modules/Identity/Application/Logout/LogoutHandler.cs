using CareSitter.Infrastructure.Auth;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Caching.Distributed;

namespace CareSitter.Modules.Identity.Application.Logout;

/// <summary>
/// Xử lý đăng xuất:
///   1. Blacklist access token JTI vào Redis cho đến khi token hết hạn.
///   2. Xóa refresh token khỏi Redis (nếu client gửi) → logout thật, không thể refresh nữa.
/// </summary>
internal sealed class LogoutHandler : IRequestHandler<LogoutCommand, Result>
{
    private readonly IDistributedCache _cache;
    private readonly IJwtTokenService  _jwtTokenService;

    public LogoutHandler(IDistributedCache cache, IJwtTokenService jwtTokenService)
    {
        _cache           = cache;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<Result> Handle(LogoutCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Jti))
            return Error.Validation("auth.missing_token_id", "Access token không có mã định danh để đăng xuất.");

        // 1. Blacklist access token JTI
        var now = DateTimeOffset.UtcNow;
        if (request.ExpiresAtUtc > now)
        {
            var ttl = request.ExpiresAtUtc - now;
            await _cache.SetStringAsync(
                JwtRevocationCacheKeys.RevokedAccessToken(request.Jti),
                "revoked",
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = ttl
                }, ct);
        }

        // 2. Xóa refresh token khỏi Redis (nếu client gửi)
        // → refresh token cũ không thể dùng nữa dù chưa hết TTL 7 ngày
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            var hashed    = _jwtTokenService.HashRefreshToken(request.RefreshToken);
            var redisKey  = JwtRevocationCacheKeys.RefreshToken(hashed);
            await _cache.RemoveAsync(redisKey, ct);
        }

        return Result.Success();
    }
}