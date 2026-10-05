using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class ChangePasswordCommandHandler(
    IIdentityStore store,
    ICurrentUser currentUser,
    IPasswordHasher passwordHasher,
    IRefreshTokenSessionService sessions)
    : IRequestHandler<ChangePasswordCommand, Result<string>>
{
    public async Task<Result<string>> Handle(ChangePasswordCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        if (string.IsNullOrWhiteSpace(request.CurrentPassword))
            return Error.Validation("password.current_required", "Vui lòng nhập mật khẩu hiện tại.");
        if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 8)
            return Error.Validation("password.policy", "Mật khẩu mới phải có ít nhất 8 ký tự.");
        if (request.NewPassword == request.CurrentPassword)
            return Error.Validation("password.same", "Mật khẩu mới phải khác mật khẩu hiện tại.");

        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        if (user.PasswordHash is null)
            return Error.Validation("password.no_password",
                "Tài khoản này không dùng đăng nhập bằng mật khẩu.");
        if (!passwordHasher.Verify(request.CurrentPassword, user.PasswordHash))
            return Error.Validation("password.incorrect", "Mật khẩu hiện tại không chính xác.");

        user.SetPassword(passwordHasher.Hash(request.NewPassword));
        await store.SaveChangesAsync(ct);
        await sessions.RevokeAllForUserAsync(userId, ct);
        return "Đổi mật khẩu thành công. Vui lòng đăng nhập lại.";
    }
}
