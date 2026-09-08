using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Identity.Application.Login;

/// <summary>
/// Xử lý yêu cầu đăng nhập bằng Email + OTP.
/// Xác minh mã OTP bằng Redis Distributed Cache thay vì cơ sở dữ liệu.
/// </summary>
internal sealed class LoginHandler : IRequestHandler<LoginCommand, Result<LoginResponse>>
{
    private readonly IdentityDbContext _db;
    private readonly IDistributedCache _cache;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly JwtSettings _jwtSettings;

    public LoginHandler(
        IdentityDbContext db,
        IDistributedCache cache,
        IJwtTokenService jwtTokenService,
        IOptions<JwtSettings> jwtSettingsOptions)
    {
        _db = db;
        _cache = cache;
        _jwtTokenService = jwtTokenService;
        _jwtSettings = jwtSettingsOptions.Value;
    }

    /// <summary>
    /// Xác minh OTP từ Redis, ghi nhận thời gian đăng nhập, và phát hành JWT tokens.
    /// </summary>
    public async Task<Result<LoginResponse>> Handle(LoginCommand request, CancellationToken ct)
    {
        var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;
        var otp = request.Otp?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(email))
            return Error.Validation("auth.email_required", "Địa chỉ email là bắt buộc.");

        if (string.IsNullOrWhiteSpace(otp))
            return Error.Validation("auth.otp_required", "Mã OTP là bắt buộc.");

        var cacheKey = $"otp:{email}";

        // Lấy OTP từ Redis và đối chiếu
        var cachedOtp = await _cache.GetStringAsync(cacheKey, ct);
        if (cachedOtp is null || cachedOtp != otp)
        {
            return Error.Validation("auth.invalid_otp", "Mã OTP không hợp lệ hoặc đã hết hiệu lực.");
        }

        var now = DateTimeOffset.UtcNow;

        // Tìm user theo email
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null)
            return Error.NotFound("auth.user_not_found", $"Không tìm thấy tài khoản với email {email}.");

        if (user.Status != "ACTIVE")
            return Error.Failure("auth.inactive_user", $"Tài khoản đang ở trạng thái {user.Status} và không thể đăng nhập.");

        var roleRequirement = AuthRoleRequirement.Validate(user, request.RequiredRole);
        if (roleRequirement.IsFailure)
            return roleRequirement.Error;

        // Xóa mã OTP sau khi user hợp lệ và đúng role ứng dụng.
        await _cache.RemoveAsync(cacheKey, ct);

        // Ghi nhận thời gian đăng nhập gần nhất
        user.RecordLogin(now);

        await _db.SaveChangesAsync(ct);

        // Phát hành JWT Access Token và Refresh Token
        var accessToken  = _jwtTokenService.GenerateAccessToken(user.Id, user.Roles, user.DisplayName);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        // Lưu refresh token vào Redis (stateful, có thể revoke khi logout/đổi mật khẩu)
        var hashed = _jwtTokenService.HashRefreshToken(refreshToken);
        await _cache.SetStringAsync(
            JwtRevocationCacheKeys.RefreshToken(hashed),
            user.Id.ToString(),
            new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromDays(_jwtSettings.RefreshTokenExpiryDays)
            }, ct);

        return new LoginResponse(accessToken, refreshToken, user.Id, user.Roles, user.DisplayName);
    }
}
