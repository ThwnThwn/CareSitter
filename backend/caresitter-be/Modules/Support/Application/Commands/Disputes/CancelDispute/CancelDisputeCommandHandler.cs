using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CancelDispute;

internal sealed class CancelDisputeCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IAuditLogger auditLogger) : IRequestHandler<CancelDisputeCommand, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(
        CancelDisputeCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();

        var dispute = await repository.GetDisputeAsync(request.DisputeId, ct);
        if (dispute is null) return SupportErrors.NotFound();

        var before = new { dispute.Status };
        var result = dispute.Cancel();
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_DISPUTE_CANCELLED", "Dispute", dispute.Id,
            before, new { dispute.Status, dispute.BookingId }, ct);
        return SupportResponseMapper.ToResponse(dispute);
    }
}
