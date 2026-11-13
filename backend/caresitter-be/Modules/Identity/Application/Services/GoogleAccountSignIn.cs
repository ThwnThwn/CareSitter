using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

// Both trusted token verifiers resolve the same Google subject and account policy.
internal sealed class GoogleAccountSignIn(IIdentityStore store, IRefreshTokenSessionService sessions)
{
    public async Task<Result<GoogleLoginResponse>> SignInAsync(GoogleIdentity identity,
        string requiredRole, CancellationToken ct)
    {
        var googleId = identity.Subject;
        var email = identity.Email;
        var name = identity.Name;
        var now = DateTimeOffset.UtcNow;
        bool isNewUser = false;

        // --- Tìm user theo google_id trước, rồi theo email ---
        var user = await store.FindUserByGoogleIdOrEmailAsync(googleId, email, ct);

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

            store.AddUser(user);
            isNewUser = true;
        }
        else
        {
            // --- User đã tồn tại → link Google nếu chưa có ---
            if (user.Status != "ACTIVE")
                return Error.Failure("auth.inactive_user", $"Tài khoản đang ở trạng thái {user.Status}.");

            if (user.GoogleId is not null && user.GoogleId != googleId)
                return Error.Conflict("auth.google_account_conflict", "Email đã liên kết tài khoản Google khác.");
            if (user.GoogleId is null)
                user.LinkGoogle(googleId);
        }

        var roleRequirement = CareSitter.Modules.Identity.Application.Login.AuthRoleRequirement
            .Validate(user, requiredRole);
        if (roleRequirement.IsFailure)
            return roleRequirement.Error;

        user.RecordLogin(now);
        if (user.Email == email) user.VerifyEmail(now);
        await store.SaveChangesAsync(ct);

        var issued = await sessions.TryIssueAsync(user, ct);
        if (issued.IsFailure) return issued.Error;
        var tokens = issued.Value;

        return new GoogleLoginResponse(
            tokens.AccessToken, tokens.RefreshToken,
            user.Id, user.Roles, user.DisplayName,
            isNewUser);
    }
}
