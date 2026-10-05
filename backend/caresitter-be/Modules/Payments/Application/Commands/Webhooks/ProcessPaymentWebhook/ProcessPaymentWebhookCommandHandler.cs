using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ProcessPaymentWebhookCommandHandler(IPaymentWebhookProcessor processor)
    : IRequestHandler<ProcessPaymentWebhookCommand, Result<PaymentWebhookResponse>>
{
    public Task<Result<PaymentWebhookResponse>> Handle(
        ProcessPaymentWebhookCommand request, CancellationToken ct) =>
        processor.ProcessAsync(request, ct);
}
