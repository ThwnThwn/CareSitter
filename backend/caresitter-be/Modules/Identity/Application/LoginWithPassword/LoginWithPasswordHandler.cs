using BCrypt.Net;
using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Identity.Application.LoginWithPassword;

/// <summary>
/// Xử lý yêu cầu đăng nhập bằng Email + mật khẩu.
/// Xác minh mật khẩu bằng BCrypt verify thay vì OTP Redis.
/// </summary>
internal sealed class LoginWithPasswordHandler : IRequestHandler<LoginWithPasswordCommand, Result<LoginResponse>>
{
    private readonly IdentityDbContext _db;
    private readonly IDistributedCache _cache;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly JwtSettings _jwtSettings;

    public LoginWithPasswordHandler(
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
    /// Tìm user theo email, xác minh mật khẩu, ghi nhận login và phát hành JWT tokens.
    /// </summary>
    public async Task<Result<LoginResponse>> Handle(LoginWithPasswordCommand request, CancellationToken ct)
    {
        var identifier = request.Email?.Trim() ?? string.Empty;
        var identifierLower = identifier.ToLowerInvariant();

        if (string.IsNullOrWhiteSpace(identifier))
            return Error.Validation("auth.identifier_required", "Email hoặc số điện thoại là bắt buộc.");

        if (string.IsNullOrWhiteSpace(request.Password))
            return Error.Validation("auth.password_required", "Mật khẩu là bắt buộc.");

        // Tìm user theo email hoặc số điện thoại
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Email == identifierLower || (u.Phone != null && u.Phone == identifier), ct);

        // Trả về cùng thông báo lỗi dù tài khoản sai hay password sai (tránh user enumeration)
        if (user is null || user.PasswordHash is null)
            return Error.Validation("auth.invalid_credentials", "Tài khoản hoặc mật khẩu không chính xác.");

        if (user.Status != "ACTIVE")
            return Error.Failure("auth.inactive_user", $"Tài khoản đang ở trạng thái {user.Status} và không thể đăng nhập.");

        // Xác minh mật khẩu với BCrypt
        var isValidPassword = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
        if (!isValidPassword)
            return Error.Validation("auth.invalid_credentials", "Email hoặc mật khẩu không chính xác.");

        var roleRequirement = AuthRoleRequirement.Validate(user, request.RequiredRole);
        if (roleRequirement.IsFailure)
            return roleRequirement.Error;

        // Ghi nhận thời gian đăng nhập
        user.RecordLogin(DateTimeOffset.UtcNow);
        await _db.SaveChangesAsync(ct);

        // Phát hành JWT Access Token và Refresh Token
        var accessToken  = _jwtTokenService.GenerateAccessToken(user.Id, user.Roles, user.DisplayName);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        // Lưu refresh token vào Redis (stateful)
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
