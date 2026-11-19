using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.ResolveDispute;

internal sealed class ResolveDisputeCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IDisputeBookingWorkflow bookingWorkflow,
    IWalletService wallet,
    IDisputePricing pricing,
    IAuditLogger auditLogger) : IRequestHandler<ResolveDisputeCommand, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(
        ResolveDisputeCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        if (currentUser.UserId is not { } adminId) return SupportErrors.Unauthenticated();

        var dispute = await repository.GetDisputeAsync(request.DisputeId, ct);
        if (dispute is null) return SupportErrors.NotFound();

        var booking = await bookingWorkflow.GetAsync(dispute.BookingId, ct);
        if (booking is null) return SupportErrors.DisputeBookingNotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return SupportErrors.DisputeCaregiverMissing();


        var before = new { dispute.Status, dispute.Decision, dispute.RefundAmount, dispute.CaregiverPenaltyAmount };
        var decision = request.Decision?.Trim().ToUpperInvariant() ?? string.Empty;
        var quote = pricing.Quote(booking, decision, request.RefundAmount, request.CaregiverPenaltyAmount);
        if (quote.IsFailure) return quote.Error;
        if (request.ExpectedQuote is { } expected && expected != quote.Value)
            return Error.Conflict("dispute.quote_changed", "Phân bổ tiền đã thay đổi. Vui lòng kiểm tra và xác nhận lại.");
        long? effectiveRefund = quote.Value.Refund;
        if (dispute.Status == "RESOLVED" && dispute.Decision == decision &&
            dispute.RefundAmount == effectiveRefund && (dispute.CaregiverPenaltyAmount ?? 0) == (request.CaregiverPenaltyAmount ?? 0))
            return SupportResponseMapper.ToResponse(dispute);
        if (booking.Status != "disputed") return SupportErrors.DisputeInvalidState();
        var result = dispute.Resolve(adminId, decision,
            effectiveRefund, request.CaregiverPenaltyAmount);
        if (result.IsFailure) return result.Error;

        var refundState = OriginalPaymentRefundState.NotRequired;
        if (effectiveRefund is > 0)
        {
            var refund = await wallet.RequestOriginalPaymentRefundAsync(
                booking.BookingId,
                booking.CustomerId,
                effectiveRefund.Value,
                $"DISPUTE_{decision}",
                ct);
            if (refund.IsFailure) return refund.Error;
            if (refund.Value.State == OriginalPaymentRefundState.NotRequired)
                return Error.Conflict("support.dispute.payment_missing",
                    "Không tìm thấy giao dịch gốc đã thu tiền để hoàn; cần đối soát thủ công.");
            refundState = refund.Value.State;
        }

        var financial = await wallet.ResolveDisputeAsync(
            booking.BookingId,
            caregiverId,
            booking.EscrowAmount,
            booking.CustomerPayableAmount,
            booking.PromotionSubsidyAmount,
            booking.PlatformFeeAmount,
            decision,
            effectiveRefund,
            request.CaregiverPenaltyAmount,
            ct);
        if (financial.IsFailure) return financial.Error;

        var resolvedAt = dispute.ResolvedAt ?? DateTimeOffset.UtcNow;
        var bookingResult = await bookingWorkflow.ResolveAsync(
            booking.BookingId, decision, effectiveRefund ?? 0,
            refundState, resolvedAt, ct);
        if (bookingResult.IsFailure) return bookingResult.Error;

        await repository.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_DISPUTE_RESOLVED", "Dispute", dispute.Id,
            before, new
            {
                dispute.Status,
                dispute.Decision,
                dispute.RefundAmount,
                dispute.CaregiverPenaltyAmount,
                dispute.BookingId
            }, ct);
        return SupportResponseMapper.ToResponse(dispute);
    }
}
