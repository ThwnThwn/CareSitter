using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public interface IPaymentWebhookProcessor
{
    Task<Result<PaymentWebhookResponse>> ProcessAsync(
        ProcessPaymentWebhookCommand request, CancellationToken ct = default);
}
