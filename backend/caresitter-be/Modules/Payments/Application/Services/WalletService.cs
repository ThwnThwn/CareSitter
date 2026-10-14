using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

internal sealed class WalletService(IWalletLedgerStore ledger,
    IDisputeLookupService disputeLookup, IPeopleLookupService peopleLookup) : IWalletService
{
    public Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default) =>
        ledger.LockEscrowAsync(bookingId, amount, idempotencyKey, ct);

    public Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount, CancellationToken ct = default)
    {
        if (amount == 0) return Task.FromResult(Result.Success());
        if (amount < 0) return Task.FromResult(Result.Failure(Error.Validation(
            "payments.promotion_subsidy", "Số tiền tài trợ promotion không được âm.")));
        return ledger.RecordPromotionSubsidyAsync(bookingId, amount, ct);
    }

    public Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct = default) =>
        ledger.ReleaseEscrowAsync(bookingId, amount, ct);

    public Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId, CancellationToken ct = default) =>
        ledger.RefundToCustomerWalletAsync(bookingId, customerId, ct);

    public async Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount,
        long platformFeeAmount, CancellationToken ct = default)
    {
        if (await disputeLookup.HasOpenDisputeAsync(bookingId, ct))
            return Error.Conflict("payments.dispute_open", "Booking dang co dispute mo, không thể giai ngan escrow.");
        var caregiverUserId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return Error.NotFound("payments.caregiver_not_found", "Không tìm thấy tài khoản của caregiver.");
        var caregiverAmount = escrowAmount - platformFeeAmount;
        if (caregiverAmount <= 0)
            return Error.Validation("payments.invalid_settlement_amount", "Số tiền caregiver nhận phải lớn hơn 0.");
        return await ledger.SettleAsync(bookingId, caregiverUserId.Value, caregiverAmount, platformFeeAmount, ct);
    }

    public async Task<Result> ResolveDisputeAsync(Guid bookingId, Guid customerId, Guid caregiverId,
        long escrowAmount, long platformFeeAmount, string decision, long? refundAmount,
        long? caregiverPenaltyAmount, CancellationToken ct = default)
    {
        var allocation = DisputeAllocation.Create(escrowAmount, platformFeeAmount, decision,
            refundAmount, caregiverPenaltyAmount);
        if (allocation.IsFailure) return allocation.Error;
        var caregiverUserId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return Error.NotFound("payments.caregiver_not_found", "Không tìm thấy tài khoản caregiver.");
        return await ledger.ResolveDisputeAsync(bookingId, customerId, caregiverUserId.Value, allocation.Value, ct);
    }

    public async Task<Result> ReleaseMatureSettlementAsync(
        Guid bookingId,
        Guid caregiverId,
        long escrowAmount,
        long platformFeeAmount,
        DateTimeOffset releasedAt,
        CancellationToken ct = default)
    {
        if (await disputeLookup.HasOpenDisputeAsync(bookingId, ct))
            return Error.Conflict("payments.settlement.not_mature",
                "Settlement chưa đến hạn hoặc booking đang có dispute.");

        // Booking owns maturity/status validation and stamps SettlementReleasedAt
        // after this idempotent Payments operation succeeds.
        return await SettleAsync(
            bookingId, caregiverId, escrowAmount, platformFeeAmount, ct);
    }
}
