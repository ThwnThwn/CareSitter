using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ProcessPaymentWebhookCommand(
    string Provider,
    string ProviderEventId,
    string? EventType = null,
    string? ProviderTransactionId = null,
    string? ProviderOrderRef = null,
    string? Payload = null) : IRequest<Result<PaymentWebhookResponse>>;

public sealed record PaymentWebhookResponse(string Status, Guid? WebhookId = null);

public interface IPaymentWebhookProcessor
{
    Task<Result<PaymentWebhookResponse>> ProcessAsync(
        ProcessPaymentWebhookCommand request, CancellationToken ct = default);
}

internal sealed class ProcessPaymentWebhookCommandHandler(IPaymentWebhookProcessor processor)
    : IRequestHandler<ProcessPaymentWebhookCommand, Result<PaymentWebhookResponse>>
{
    public Task<Result<PaymentWebhookResponse>> Handle(
        ProcessPaymentWebhookCommand request, CancellationToken ct) =>
        processor.ProcessAsync(request, ct);
}
