using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed record ConfirmManualRefundCommand(
    Guid RefundRequestId,
    string ProviderRefundId,
    string ConfirmationNote) : IRequest<Result<RefundResponse>>;

internal sealed class ConfirmManualRefundCommandHandler(
    IRefundStore store,
    ICurrentUser currentUser,
    IAuditLogger auditLogger)
    : IRequestHandler<ConfirmManualRefundCommand, Result<RefundResponse>>
{
    public async Task<Result<RefundResponse>> Handle(
        ConfirmManualRefundCommand request,
        CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN"))
            return Error.Forbidden("refund.forbidden", "Chỉ admin được xác nhận refund thủ công.");
        if (currentUser.UserId is not { } adminId)
            return Error.Unauthorized("refund.unauthenticated", "Chưa đăng nhập.");
        if (request.ProviderRefundId.Trim().Length is < 3 or > 255)
            return Error.Validation("refund.provider_refund_id", "Mã refund provider dài 3-255 ký tự.");
        if (request.ConfirmationNote.Trim().Length is < 10 or > 1000)
            return Error.Validation("refund.confirmation_note", "Ghi chú đối soát dài 10-1000 ký tự.");

        var result = await store.ConfirmManualAsync(
            request.RefundRequestId,
            adminId,
            request.ProviderRefundId,
            request.ConfirmationNote,
            DateTimeOffset.UtcNow,
            ct);
        if (result.IsFailure) return result.Error;

        await auditLogger.WriteAsync(
            "ADMIN_ORIGINAL_PAYMENT_REFUND_CONFIRMED",
            "RefundRequest",
            result.Value.Id,
            new { Status = "MANUAL_REQUIRED" },
            new
            {
                result.Value.Status,
                result.Value.Provider,
                result.Value.Amount,
                result.Value.ProviderRefundId,
                result.Value.CompletedAt
            },
            ct);
        return result.Value;
    }
}
