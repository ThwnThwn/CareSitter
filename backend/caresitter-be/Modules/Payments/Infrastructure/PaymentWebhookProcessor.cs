using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PaymentWebhookProcessor(PaymentsDbContext db) : IPaymentWebhookProcessor
{
    public async Task<Result<PaymentWebhookResponse>> ProcessAsync(
        ProcessPaymentWebhookCommand request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Provider) ||
            string.IsNullOrWhiteSpace(request.ProviderEventId))
            return Error.Validation("payments.webhook.required",
                "provider va provider_event_id la bat buoc.");

        var alreadyReceived = await db.PaymentWebhooks.AsNoTracking().AnyAsync(
            x => x.Provider == request.Provider &&
                 x.ProviderEventId == request.ProviderEventId, ct);
        if (alreadyReceived) return new PaymentWebhookResponse("ALREADY_PROCESSED");

        var webhook = PaymentWebhook.Create(request.Provider, request.ProviderEventId,
            request.EventType, request.Payload);
        if (webhook.IsFailure) return webhook.Error;
        db.PaymentWebhooks.Add(webhook.Value);

        if (request.EventType is "PAYMENT_SUCCESS" or "payment.success")
        {
            var intent = await FindOpenIntentAsync(request, ct);
            if (intent is not null && !string.IsNullOrWhiteSpace(request.ProviderTransactionId))
            {
                var marked = intent.MarkSucceeded(request.ProviderTransactionId, request.Payload);
                if (marked.IsSuccess)
                {
                    var ledger = LedgerEntry.Create("ESCROW_LOCK",
                        $"customer:{intent.CustomerId}", "escrow:platform",
                        intent.Amount, intent.BookingId, intent.Id);
                    if (ledger.IsSuccess) db.LedgerEntries.Add(ledger.Value);
                }
            }
        }
        else if (request.EventType is "PAYMENT_FAILED" or "payment.failed")
        {
            var intent = await FindOpenIntentAsync(request, ct);
            intent?.MarkFailed(request.Payload);
        }

        webhook.Value.MarkProcessed();
        await db.SaveChangesAsync(ct);
        return new PaymentWebhookResponse("OK", webhook.Value.Id);
    }

    private Task<PaymentIntent?> FindOpenIntentAsync(
        ProcessPaymentWebhookCommand request, CancellationToken ct) =>
        db.PaymentIntents.FirstOrDefaultAsync(x => x.Provider == request.Provider
            && (request.ProviderOrderRef != null && x.ProviderOrderRef == request.ProviderOrderRef
                || request.ProviderTransactionId != null &&
                   x.ProviderTransactionId == request.ProviderTransactionId)
            && x.Status != "SUCCEEDED" && x.Status != "FAILED", ct);
}
