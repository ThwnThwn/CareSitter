using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.ResolveDispute;

internal sealed class ResolveDisputeCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser) : IRequestHandler<ResolveDisputeCommand, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(
        ResolveDisputeCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        if (currentUser.UserId is not { } adminId) return SupportErrors.Unauthenticated();

        var dispute = await repository.GetDisputeAsync(request.DisputeId, ct);
        if (dispute is null) return SupportErrors.NotFound();

        var result = dispute.Resolve(adminId, request.Decision,
            request.RefundAmount, request.CaregiverPenaltyAmount);
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(dispute);
    }
}
