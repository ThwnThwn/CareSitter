using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Xử lý yêu cầu đăng nhập / đăng ký bằng Google ID Token.
/// Verify token với Google, tìm hoặc tạo user, phát hành JWT.
/// </summary>
internal sealed class GoogleLoginHandler : IRequestHandler<GoogleLoginCommand, Result<GoogleLoginResponse>>
{
    private readonly IIdentityStore _store;
    private readonly IRefreshTokenSessionService _sessions;
    private readonly IGoogleIdentityVerifier _googleIdentityVerifier;

    public GoogleLoginHandler(
        IIdentityStore store,
        IRefreshTokenSessionService sessions,
        IGoogleIdentityVerifier googleIdentityVerifier)
    {
        _store = store;
        _sessions = sessions;
        _googleIdentityVerifier = googleIdentityVerifier;
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
        // Defense in depth: command có thể được gọi ngoài HTTP controller.
        // Không bao giờ cho phép Google self-registration cấp ADMIN.
        var roleResult = GoogleLoginRolePolicy.Validate(request.RequiredRole);
        if (roleResult.IsFailure)
            return roleResult.Error;
        var requiredRole = roleResult.Value;

        if (string.IsNullOrWhiteSpace(request.IdToken))
            return Error.Validation("auth.google_token_required", "Google ID Token là bắt buộc.");

        var verified = await _googleIdentityVerifier.VerifyAsync(request.IdToken, ct);
        if (verified.IsFailure) return verified.Error;
        var googleId = verified.Value.Subject;
        var email = verified.Value.Email;
        var name = verified.Value.Name;

        var now = DateTimeOffset.UtcNow;
        bool isNewUser = false;

        // --- Tìm user theo google_id trước, rồi theo email ---
        var user = await _store.FindUserByGoogleIdOrEmailAsync(googleId, email, ct);

        if (user is null)
        {
            // --- Tạo user mới (auto-register qua Google) ---
            var userResult = User.Create(Guid.NewGuid(), email);
            if (userResult.IsFailure)
                return userResult.Error;

            user = userResult.Value;
            user.UpdateProfile(name, email, name);
            user.SetRoles([requiredRole]);
            user.LinkGoogle(googleId);

            _store.AddUser(user);
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

        var roleRequirement = CareSitter.Modules.Identity.Application.Login.AuthRoleRequirement
            .Validate(user, requiredRole);
        if (roleRequirement.IsFailure)
            return roleRequirement.Error;

        user.RecordLogin(now);
        if (user.Email == email) user.VerifyEmail(now);
        await _store.SaveChangesAsync(ct);

        var issued = await _sessions.TryIssueAsync(user, ct);
        if (issued.IsFailure) return issued.Error;
        var tokens = issued.Value;

        return new GoogleLoginResponse(
            tokens.AccessToken, tokens.RefreshToken,
            user.Id, user.Roles, user.DisplayName,
            isNewUser);
    }
}
