using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CancelDispute;

internal sealed class CancelDisputeCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser) : IRequestHandler<CancelDisputeCommand, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(
        CancelDisputeCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();

        var dispute = await repository.GetDisputeAsync(request.DisputeId, ct);
        if (dispute is null) return SupportErrors.NotFound();

        var result = dispute.Cancel();
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(dispute);
    }
}
