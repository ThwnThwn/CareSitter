using BCrypt.Net;
using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Application.LoginWithPassword;

/// <summary>
/// Xử lý yêu cầu đăng nhập bằng Email + mật khẩu.
/// Xác minh mật khẩu bằng BCrypt verify thay vì OTP Redis.
/// </summary>
internal sealed class LoginWithPasswordHandler : IRequestHandler<LoginWithPasswordCommand, Result<LoginResponse>>
{
    private readonly IdentityDbContext _db;
    private readonly IJwtTokenService _jwtTokenService;

    public LoginWithPasswordHandler(IdentityDbContext db, IJwtTokenService jwtTokenService)
    {
        _db = db;
        _jwtTokenService = jwtTokenService;
    }

    /// <summary>
    /// Tìm user theo email, xác minh mật khẩu, ghi nhận login và phát hành JWT tokens.
    /// </summary>
    public async Task<Result<LoginResponse>> Handle(LoginWithPasswordCommand request, CancellationToken ct)
    {
        var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(email))
            return Error.Validation("auth.email_required", "Địa chỉ email là bắt buộc.");

        if (string.IsNullOrWhiteSpace(request.Password))
            return Error.Validation("auth.password_required", "Mật khẩu là bắt buộc.");

        // Tìm user theo email
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        // Trả về cùng thông báo lỗi dù email sai hay password sai (tránh user enumeration)
        if (user is null || user.PasswordHash is null)
            return Error.Validation("auth.invalid_credentials", "Email hoặc mật khẩu không chính xác.");

        if (user.Status != "ACTIVE")
            return Error.Failure("auth.inactive_user", $"Tài khoản đang ở trạng thái {user.Status} và không thể đăng nhập.");

        // Xác minh mật khẩu với BCrypt
        var isValidPassword = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
        if (!isValidPassword)
            return Error.Validation("auth.invalid_credentials", "Email hoặc mật khẩu không chính xác.");

        // Ghi nhận thời gian đăng nhập
        user.RecordLogin(DateTimeOffset.UtcNow);
        await _db.SaveChangesAsync(ct);

        // Phát hành JWT Access Token và Refresh Token
        var accessToken = _jwtTokenService.GenerateAccessToken(user.Id, user.Roles, user.DisplayName);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        return new LoginResponse(accessToken, refreshToken, user.Id, user.Roles, user.DisplayName);
    }
}
