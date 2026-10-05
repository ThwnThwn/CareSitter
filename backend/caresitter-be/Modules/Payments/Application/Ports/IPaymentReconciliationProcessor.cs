using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public interface IPaymentReconciliationProcessor
{
    Task<IReadOnlyList<PaymentReconciliationItem>> ListAsync(CancellationToken ct = default);
    Task<Result<PaymentReviewResolution>> ResolveAsync(
        ResolvePaymentReviewCommand command, CancellationToken ct = default);
}
