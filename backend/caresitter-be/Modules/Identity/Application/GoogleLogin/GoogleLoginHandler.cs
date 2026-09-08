using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Results;
using Google.Apis.Auth;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Xử lý yêu cầu đăng nhập / đăng ký bằng Google ID Token.
/// Verify token với Google, tìm hoặc tạo user, phát hành JWT.
/// </summary>
internal sealed class GoogleLoginHandler : IRequestHandler<GoogleLoginCommand, Result<GoogleLoginResponse>>
{
    private readonly IdentityDbContext _db;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IDistributedCache _cache;
    private readonly JwtSettings _jwtSettings;
    private readonly string _googleClientId;

    private static readonly string[] DefaultRoles = { "CUSTOMER" };
    private static readonly string[] AllowedRoles  = { "CUSTOMER", "CAREGIVER", "ADMIN" };

    public GoogleLoginHandler(
        IdentityDbContext db,
        IJwtTokenService jwtTokenService,
        IDistributedCache cache,
        IOptions<JwtSettings> jwtSettingsOptions,
        IConfiguration configuration)
    {
        _db = db;
        _jwtTokenService = jwtTokenService;
        _cache = cache;
        _jwtSettings = jwtSettingsOptions.Value;
        _googleClientId = configuration["Google:ClientId"]
            ?? throw new InvalidOperationException("Google:ClientId chưa được cấu hình trong appsettings / .env.");
    }

    /// <summary>
    /// 1. Verify Google ID Token với Google public keys.
    /// 2. Lấy email, sub, name từ payload.
    /// 3. Tìm user theo google_id hoặc email.
    /// 4. Tạo mới hoặc link google_id vào account hiện tại.
    /// 5. Phát hành JWT tokens.
    /// </summary>
    public async Task<Result<GoogleLoginResponse>> Handle(GoogleLoginCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.IdToken))
            return Error.Validation("auth.google_token_required", "Google ID Token là bắt buộc.");

        // --- Verify Google ID Token ---
        GoogleJsonWebSignature.Payload payload;
        try
        {
            var validationSettings = new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = new[] { _googleClientId }
            };
            payload = await GoogleJsonWebSignature.ValidateAsync(request.IdToken, validationSettings);
        }
        catch (InvalidJwtException)
        {
            return Error.Validation("auth.invalid_google_token", "Google ID Token không hợp lệ hoặc đã hết hạn.");
        }

        var googleId = payload.Subject;  // Google "sub" claim — ID duy nhất trên Google
        var email    = payload.Email?.Trim().ToLowerInvariant() ?? string.Empty;
        var name     = payload.Name ?? email;

        if (string.IsNullOrWhiteSpace(email))
            return Error.Validation("auth.google_email_missing", "Tài khoản Google không cung cấp địa chỉ email.");

        // Validate roles nếu được truyền vào
        var roles = request.Roles?.Select(r => r.ToUpper()).ToArray() ?? Array.Empty<string>();
        foreach (var role in roles)
        {
            if (!AllowedRoles.Contains(role))
                return Error.Validation("auth.invalid_role", $"Vai trò '{role}' không hợp lệ.");
        }

        var requiredRoleResult = AuthRoleRequirement.Normalize(request.RequiredRole);
        if (requiredRoleResult.IsFailure)
            return requiredRoleResult.Error;
        var requiredRole = requiredRoleResult.Value;

        var now = DateTimeOffset.UtcNow;
        bool isNewUser = false;

        // --- Tìm user theo google_id trước, rồi theo email ---
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.GoogleId == googleId, ct)
            ?? await _db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null)
        {
            // --- Tạo user mới (auto-register qua Google) ---
            var finalRoles = roles.Length > 0
                ? roles
                : requiredRole is not null
                    ? new[] { requiredRole }
                    : DefaultRoles;
            var userResult = User.Create(Guid.NewGuid(), email);
            if (userResult.IsFailure)
                return userResult.Error;

            user = userResult.Value;
            user.UpdateProfile(name, email, name);
            user.SetRoles(finalRoles);
            user.LinkGoogle(googleId);

            _db.Users.Add(user);
            isNewUser = true;
        }
        else
        {
            // --- User đã tồn tại → link Google nếu chưa có ---
            if (user.Status != "ACTIVE")
                return Error.Failure("auth.inactive_user", $"Tài khoản đang ở trạng thái {user.Status}.");

            if (user.GoogleId is null)
                user.LinkGoogle(googleId);
        }

        var roleRequirement = AuthRoleRequirement.Validate(user, requiredRole);
        if (roleRequirement.IsFailure)
            return roleRequirement.Error;

        user.RecordLogin(now);
        await _db.SaveChangesAsync(ct);

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

        return new GoogleLoginResponse(
            accessToken, refreshToken,
            user.Id, user.Roles, user.DisplayName,
            isNewUser);
    }
}
