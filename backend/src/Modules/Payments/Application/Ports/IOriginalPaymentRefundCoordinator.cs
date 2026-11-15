using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

internal interface IOriginalPaymentRefundCoordinator
{
    Task<Result<OriginalPaymentRefundOutcome>> EnsureRefundAsync(
        Guid bookingId,
        Guid customerId,
        long? amount,
        string reason,
        CancellationToken ct = default);
}
