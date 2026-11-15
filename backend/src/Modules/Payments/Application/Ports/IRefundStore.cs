using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

internal sealed record RefundWorkItem(RefundRequest Request, Guid LeaseId, bool Submit);

internal interface IRefundStore
{
    Task<Result<OriginalPaymentRefundOutcome>> EnsureRefundAsync(
        Guid bookingId,
        Guid customerId,
        long? amount,
        string reason,
        CancellationToken ct = default);

    Task<RefundWorkItem?> ClaimNextAsync(
        DateTimeOffset now,
        DateTimeOffset leaseUntil,
        DateTimeOffset nextAttemptAt,
        CancellationToken ct = default);

    Task<Result> ApplyProviderResultAsync(
        Guid refundRequestId,
        Guid leaseId,
        RefundProviderResult result,
        DateTimeOffset completedAt,
        DateTimeOffset nextAttemptAt,
        CancellationToken ct = default);

    Task<RefundPage> ListForAdminAsync(
        string? status,
        int page,
        int pageSize,
        CancellationToken ct = default);

    Task<CustomerRefundPage> ListForCustomerAsync(
        Guid customerId,
        int page,
        int pageSize,
        CancellationToken ct = default);

    Task<Result<RefundResponse>> ConfirmManualAsync(
        Guid refundRequestId,
        Guid adminId,
        string providerRefundId,
        string confirmationNote,
        DateTimeOffset confirmedAt,
        CancellationToken ct = default);
}
