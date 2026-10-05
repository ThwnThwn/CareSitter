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
