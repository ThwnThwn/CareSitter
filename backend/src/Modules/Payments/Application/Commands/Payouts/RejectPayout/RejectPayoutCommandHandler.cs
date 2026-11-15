using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.RejectPayout;

internal sealed class RejectPayoutCommandHandler(
    IPayoutStore store,
    ICurrentUser currentUser,
    IAuditLogger auditLogger,
    PayoutMapper mapper)
    : IRequestHandler<RejectPayoutCommand, Result<PayoutResponse>>
{
    public async Task<Result<PayoutResponse>> Handle(
        RejectPayoutCommand request,
        CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN"))
            return PayoutErrors.Forbidden();
        if (currentUser.UserId is not { } adminId)
            return PayoutErrors.Unauthenticated();

        var rejected = await store.RejectAsync(request.PayoutId, adminId, request.Reason, ct);
        if (rejected.IsFailure) return rejected.Error;
        var payout = rejected.Value;
        var before = new { Status = "PENDING", payout.Amount, payout.WalletAccountId };
        await auditLogger.WriteAsync(
            "ADMIN_PAYOUT_REJECTED",
            "PayoutRequest",
            payout.Id,
            before,
            new
            {
                payout.Status,
                payout.Amount,
                payout.WalletAccountId,
                payout.ReviewedByAdminId,
                payout.ReviewedAt,
                payout.RejectReason
            },
            ct);

        return mapper.ToResponse(payout);
    }
}
