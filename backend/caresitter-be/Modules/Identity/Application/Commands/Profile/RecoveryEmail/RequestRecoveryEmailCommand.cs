using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record RequestRecoveryEmailCommand(string? NewEmail, string? CurrentPassword) : IRequest<Result<RecoveryChallengeResponse>>;
internal sealed class RequestRecoveryEmailHandler(IPasswordRecoveryService recovery, ICurrentUser currentUser)
    : IRequestHandler<RequestRecoveryEmailCommand, Result<RecoveryChallengeResponse>>
{
    public Task<Result<RecoveryChallengeResponse>> Handle(RequestRecoveryEmailCommand request, CancellationToken ct)
        => currentUser.UserId is { } id ? recovery.RequestEmailAsync(id, request.NewEmail, request.CurrentPassword, ct)
            : Task.FromResult(Result.Failure<RecoveryChallengeResponse>(Error.Unauthorized("auth.required", "Vui lòng đăng nhập.")));
}
