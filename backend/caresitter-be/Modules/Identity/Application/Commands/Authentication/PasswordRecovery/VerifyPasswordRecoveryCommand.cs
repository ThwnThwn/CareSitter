using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record VerifyPasswordRecoveryCommand(Guid ChallengeId, string Code) : IRequest<Result<RecoveryGrantResponse>>;
internal sealed class VerifyPasswordRecoveryHandler(IPasswordRecoveryService recovery)
    : IRequestHandler<VerifyPasswordRecoveryCommand, Result<RecoveryGrantResponse>>
{
    public Task<Result<RecoveryGrantResponse>> Handle(VerifyPasswordRecoveryCommand request, CancellationToken ct)
        => recovery.VerifyAsync(request.ChallengeId, request.Code, ct);
}
