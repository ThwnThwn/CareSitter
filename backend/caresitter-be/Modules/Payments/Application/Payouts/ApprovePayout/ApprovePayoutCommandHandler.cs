using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;

internal sealed class ApprovePayoutCommandHandler(
    IPayoutStore store,
    ICurrentUser currentUser,
    IAuditLogger auditLogger,
    PayoutMapper mapper)
    : IRequestHandler<ApprovePayoutCommand, Result<PayoutResponse>>
{
    public async Task<Result<PayoutResponse>> Handle(
        ApprovePayoutCommand request,
        CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN"))
            return PayoutErrors.Forbidden();
        if (currentUser.UserId is not { } adminId)
            return PayoutErrors.Unauthenticated();

        var approved = await store.ApproveAsync(request.PayoutId, adminId, ct);
        if (approved.IsFailure) return approved.Error;
        var payout = approved.Value;
        var before = new { Status = "PENDING", payout.Amount, payout.WalletAccountId };
        await auditLogger.WriteAsync(
            "ADMIN_PAYOUT_APPROVED",
            "PayoutRequest",
            payout.Id,
            before,
            new
            {
                payout.Status,
                payout.Amount,
                payout.WalletAccountId,
                payout.ReviewedByAdminId,
                payout.ReviewedAt
            },
            ct);

        return mapper.ToResponse(payout);
    }
}
