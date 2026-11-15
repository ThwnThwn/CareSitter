using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ResolvePaymentReviewCommandHandler(
    IPaymentReconciliationProcessor processor)
    : IRequestHandler<ResolvePaymentReviewCommand, Result<PaymentReviewResolution>>
{
    public Task<Result<PaymentReviewResolution>> Handle(
        ResolvePaymentReviewCommand request, CancellationToken ct) =>
        processor.ResolveAsync(request, ct);
}
