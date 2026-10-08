using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record RequestPasswordRecoveryCommand(string Email) : IRequest<Result<RecoveryChallengeResponse>>;
internal sealed class RequestPasswordRecoveryHandler(IPasswordRecoveryService recovery)
    : IRequestHandler<RequestPasswordRecoveryCommand, Result<RecoveryChallengeResponse>>
{
    public Task<Result<RecoveryChallengeResponse>> Handle(RequestPasswordRecoveryCommand request, CancellationToken ct)
        => recovery.RequestAsync(request.Email, ct);
}
