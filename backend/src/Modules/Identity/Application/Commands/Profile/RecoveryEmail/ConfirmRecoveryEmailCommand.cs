using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record ConfirmRecoveryEmailCommand(Guid ChallengeId, string Code) : IRequest<Result<RecoveryEmailResponse>>;
internal sealed class ConfirmRecoveryEmailHandler(IPasswordRecoveryService recovery, ICurrentUser currentUser)
    : IRequestHandler<ConfirmRecoveryEmailCommand, Result<RecoveryEmailResponse>>
{
    public Task<Result<RecoveryEmailResponse>> Handle(ConfirmRecoveryEmailCommand request, CancellationToken ct)
        => currentUser.UserId is { } id ? recovery.ConfirmEmailAsync(id, request.ChallengeId, request.Code, ct)
            : Task.FromResult(Result.Failure<RecoveryEmailResponse>(Error.Unauthorized("auth.required", "Vui lòng đăng nhập.")));
}
