using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record ResetPasswordRecoveryCommand(string ResetToken, string NewPassword, string ConfirmPassword) : IRequest<Result>;
internal sealed class ResetPasswordRecoveryHandler(IPasswordRecoveryService recovery)
    : IRequestHandler<ResetPasswordRecoveryCommand, Result>
{
    public Task<Result> Handle(ResetPasswordRecoveryCommand request, CancellationToken ct)
    {
        if (request.NewPassword != request.ConfirmPassword)
            return Task.FromResult(Result.Failure(Error.Validation("password.confirm_mismatch", "Mật khẩu xác nhận chưa khớp.")));
        var policy = PasswordPolicy.Validate(request.NewPassword);
        return policy.IsFailure ? Task.FromResult(policy) : recovery.ResetAsync(request.ResetToken, request.NewPassword, ct);
    }
}
