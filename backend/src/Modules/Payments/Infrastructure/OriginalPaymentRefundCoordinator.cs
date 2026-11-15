using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class OriginalPaymentRefundCoordinator(IRefundStore store)
    : IOriginalPaymentRefundCoordinator
{
    public Task<Result<OriginalPaymentRefundOutcome>> EnsureRefundAsync(
        Guid bookingId,
        Guid customerId,
        long? amount,
        string reason,
        CancellationToken ct = default) =>
        store.EnsureRefundAsync(bookingId, customerId, amount, reason, ct);
}
