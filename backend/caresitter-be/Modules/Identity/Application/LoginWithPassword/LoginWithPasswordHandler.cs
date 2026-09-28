using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.LoginWithPassword;

/// <summary>
/// Xử lý yêu cầu đăng nhập bằng Email + mật khẩu.
/// Xác minh mật khẩu bằng BCrypt verify thay vì OTP Redis.
/// </summary>
internal sealed class LoginWithPasswordHandler : IRequestHandler<LoginWithPasswordCommand, Result<LoginResponse>>
{
    private readonly IIdentityStore _store;
    private readonly IRefreshTokenSessionService _sessions;
    private readonly IAuthenticationAttemptLimiter _attemptLimiter;
    private readonly IPasswordHasher _passwordHasher;

    public LoginWithPasswordHandler(
        IIdentityStore store,
        IRefreshTokenSessionService sessions,
        IAuthenticationAttemptLimiter attemptLimiter,
        IPasswordHasher passwordHasher)
    {
        _store = store;
        _sessions = sessions;
        _attemptLimiter = attemptLimiter;
        _passwordHasher = passwordHasher;
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

        if (await _attemptLimiter.IsBlockedAsync("password-login", identifierLower, ct))
            return InvalidCredentials();

        // Tìm user theo email hoặc số điện thoại
        var user = await _store.FindUserByIdentifierAsync(identifierLower, identifier, ct);

        // Always execute BCrypt to keep unknown-account and bad-password timing close.
        var isValidPassword = _passwordHasher.Verify(request.Password, user?.PasswordHash);
        if (user is null || user.PasswordHash is null || !isValidPassword || user.Status != "ACTIVE")
        {
            await _attemptLimiter.RecordFailureAsync(
                "password-login", identifierLower, 5, TimeSpan.FromMinutes(15),
                TimeSpan.FromMinutes(15), ct);
            return InvalidCredentials();
        }

        var roleRequirement = AuthRoleRequirement.Validate(user, request.RequiredRole);
        if (roleRequirement.IsFailure)
            return InvalidCredentials();

        // Ghi nhận thời gian đăng nhập
        user.RecordLogin(DateTimeOffset.UtcNow);
        await _store.SaveChangesAsync(ct);
        await _attemptLimiter.ResetAsync("password-login", identifierLower, ct);

        var tokens = await _sessions.IssueAsync(user, ct);
        return new LoginResponse(tokens.AccessToken, tokens.RefreshToken, user.Id, user.Roles, user.DisplayName);
    }

    private static Error InvalidCredentials() => Error.Validation(
        "auth.invalid_credentials", "Tài khoản hoặc mật khẩu không chính xác.");
}
