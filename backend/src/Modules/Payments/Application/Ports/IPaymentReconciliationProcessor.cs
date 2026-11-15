using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public interface IPaymentReconciliationProcessor
{
    Task<PaymentPage<PaymentReconciliationItem>> ListAsync(
        int page, int pageSize, CancellationToken ct = default);
    Task<Result<PaymentReviewResolution>> ResolveAsync(
        ResolvePaymentReviewCommand command, CancellationToken ct = default);
}
