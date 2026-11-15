using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class ChangePasswordCommandHandler(
    ICurrentUser currentUser,
    IPasswordRecoveryService recovery)
    : IRequestHandler<ChangePasswordCommand, Result<string>>
{
    public async Task<Result<string>> Handle(ChangePasswordCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        if (string.IsNullOrWhiteSpace(request.CurrentPassword))
            return Error.Validation("password.current_required", "Vui lòng nhập mật khẩu hiện tại.");
        return await recovery.ChangePasswordAsync(userId, request.CurrentPassword, request.NewPassword, ct);
    }
}
