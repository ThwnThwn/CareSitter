using CareSitter.Modules.Identity.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Login;

/// <summary>
/// Xử lý yêu cầu đăng nhập bằng Email + OTP.
/// Xác minh mã OTP bằng Redis Distributed Cache thay vì cơ sở dữ liệu.
/// </summary>
internal sealed class LoginHandler : IRequestHandler<LoginCommand, Result<LoginResponse>>
{
    private readonly IIdentityStore _store;
    private readonly IOtpStore _otpStore;
    private readonly IRefreshTokenSessionService _sessions;
    private readonly IAuthenticationAttemptLimiter _attemptLimiter;

    public LoginHandler(
        IIdentityStore store,
        IOtpStore otpStore,
        IRefreshTokenSessionService sessions,
        IAuthenticationAttemptLimiter attemptLimiter)
    {
        _store = store;
        _otpStore = otpStore;
        _sessions = sessions;
        _attemptLimiter = attemptLimiter;
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

        if (await _attemptLimiter.IsBlockedAsync("otp-login", email, ct))
            return InvalidOtp();

        // Giữ phiên bản user từ trước khi kiểm OTP; reset đồng thời không được
        // biến bằng chứng OTP cũ thành một phiên mới ở phiên bản mới.
        var user = await _store.FindUserByEmailAsync(email, ct);

        // Lấy OTP từ Redis và đối chiếu
        var cachedOtp = await _otpStore.GetAsync(email, ct);
        if (cachedOtp is null || cachedOtp != otp)
        {
            await _attemptLimiter.RecordFailureAsync(
                "otp-login", email, 5, TimeSpan.FromMinutes(15),
                TimeSpan.FromMinutes(15), ct);
            return InvalidOtp();
        }

        var now = DateTimeOffset.UtcNow;

        // Tìm user theo email
        if (user is null || user.Status != "ACTIVE")
            return InvalidOtp();

        var roleRequirement = AuthRoleRequirement.Validate(user, request.RequiredRole);
        if (roleRequirement.IsFailure)
            return roleRequirement.Error;

        // Xóa mã OTP sau khi user hợp lệ và đúng role ứng dụng.
        await _otpStore.RemoveAsync(email, ct);
        await _attemptLimiter.ResetAsync("otp-login", email, ct);

        // Ghi nhận thời gian đăng nhập gần nhất
        user.RecordLogin(now);
        user.VerifyEmail(now);

        await _store.SaveChangesAsync(ct);

        var issued = await _sessions.TryIssueAsync(user, ct);
        if (issued.IsFailure) return issued.Error;
        var tokens = issued.Value;
        return new LoginResponse(tokens.AccessToken, tokens.RefreshToken, user.Id, user.Roles, user.DisplayName);
    }

    private static Error InvalidOtp() => Error.Validation(
        "auth.invalid_otp",
        "Mã OTP không hợp lệ hoặc đã hết hiệu lực.");
}
