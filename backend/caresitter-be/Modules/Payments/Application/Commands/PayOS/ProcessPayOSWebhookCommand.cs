using System.Text.Json;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ProcessPayOSWebhookCommand(JsonElement Payload) : IRequest<PayOSWebhookOutcome>;
internal sealed class ProcessPayOSWebhookCommandHandler(IPayOSPaymentPortal portal)
    : IRequestHandler<ProcessPayOSWebhookCommand, PayOSWebhookOutcome>
{
    public Task<PayOSWebhookOutcome> Handle(ProcessPayOSWebhookCommand request, CancellationToken ct) =>
        portal.ProcessWebhookAsync(request.Payload, ct);
}
