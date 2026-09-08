using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Identity.Application.RefreshToken;

/// <summary>
/// Xử lý làm mới token theo chiến lược Redis-backed stateful với token rotation.
///
/// Flow:
///   1. Hash raw refresh token → tìm key "refresh:{hash}" trong Redis.
///   2. Nếu không tìm thấy → 401 (hết hạn, đã dùng, hoặc đã logout).
///   3. Parse userId từ Redis value.
///   4. Query DB kiểm tra user ACTIVE.
///   5. Token rotation: xóa key cũ, tạo cặp token mới, lưu key mới với TTL mới.
///   6. Trả { accessToken, refreshToken }.
///
/// Bảo mật:
///   - Refresh token gốc (raw) không bao giờ lưu trong Redis — chỉ SHA-256(token) làm key.
///   - Nếu client gửi token cũ sau khi rotation → Redis miss → 401 ngay lập tức.
/// </summary>
internal sealed class RefreshTokenHandler(
    IdentityDbContext db,
    IDistributedCache cache,
    IJwtTokenService jwtTokenService,
    IOptions<JwtSettings> jwtSettingsOptions)
    : IRequestHandler<RefreshTokenCommand, Result<RefreshTokenResponse>>
{
    private readonly JwtSettings _jwtSettings = jwtSettingsOptions.Value;

    public async Task<Result<RefreshTokenResponse>> Handle(
        RefreshTokenCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
            return Error.Validation("auth.refresh_token_required", "Refresh token là bắt buộc.");

        // 1. Hash token → tìm trong Redis
        var hashed = jwtTokenService.HashRefreshToken(request.RefreshToken);
        var redisKey = JwtRevocationCacheKeys.RefreshToken(hashed);
        var storedValue = await cache.GetStringAsync(redisKey, ct);

        if (storedValue is null)
            return Error.Validation("auth.invalid_refresh_token",
                "Refresh token không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.");

        // 2. Parse userId từ Redis value (format: "userId|roles|displayName" hoặc Guid thuần)
        if (!Guid.TryParse(storedValue.Split('|')[0], out var userId))
            return Error.Validation("auth.malformed_refresh_token",
                "Dữ liệu refresh token bị hỏng. Vui lòng đăng nhập lại.");

        // 3. Kiểm tra user vẫn ACTIVE
        var user = await db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, ct);

        if (user is null)
            return Error.NotFound("auth.user_not_found", "Tài khoản không tồn tại.");

        if (user.Status != "ACTIVE")
            return Error.Validation("auth.inactive_user",
                $"Tài khoản đang ở trạng thái {user.Status}.");

        // 4. Token rotation: xóa key cũ TRƯỚC để chặn replay attack (race condition tối thiểu)
        await cache.RemoveAsync(redisKey, ct);

        // 5. Tạo cặp token mới
        var newAccessToken  = jwtTokenService.GenerateAccessToken(user.Id, user.Roles, user.DisplayName);
        var newRefreshToken = jwtTokenService.GenerateRefreshToken();

        // 6. Lưu refresh token mới vào Redis
        var newHashed = jwtTokenService.HashRefreshToken(newRefreshToken);
        var newKey    = JwtRevocationCacheKeys.RefreshToken(newHashed);
        var ttl       = TimeSpan.FromDays(_jwtSettings.RefreshTokenExpiryDays);

        // Value lưu: "userId" đủ để restore session; không lưu raw token.
        await cache.SetStringAsync(newKey, userId.ToString(), new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = ttl
        }, ct);

        return new RefreshTokenResponse(newAccessToken, newRefreshToken);
    }
}
