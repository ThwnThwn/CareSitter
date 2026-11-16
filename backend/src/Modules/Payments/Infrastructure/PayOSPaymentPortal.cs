using System.Text.Json;
using CareSitter.Modules.Payments.Application;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSPaymentPortal(
    PayOSCheckout checkout,
    PayOSPaymentReconciliation reconciliation,
    PayOSWebhookProcessor webhooks) : IPayOSPaymentPortal
{
    public Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(
        Guid bookingId, Guid userId, CancellationToken ct = default) =>
        checkout.CreateIntentAsync(bookingId, userId, ct);

    public Task RefreshAsync(Guid intentId, CancellationToken ct = default) =>
        reconciliation.RefreshAsync(intentId, ct);

    public Task<PayOSWebhookOutcome> ProcessWebhookAsync(JsonElement payload, CancellationToken ct = default) =>
        webhooks.ProcessWebhookAsync(payload, ct);

    public Task<string> GetReturnUrlAsync(string? orderCode, CancellationToken ct = default) =>
        reconciliation.GetReturnUrlAsync(orderCode, ct);
}
