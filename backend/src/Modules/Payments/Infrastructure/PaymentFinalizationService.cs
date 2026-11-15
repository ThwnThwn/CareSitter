using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Persistence.Outbox;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>
/// Finalizes Payments-owned state atomically and publishes a durable event for Booking.
/// Booking confirmation is intentionally eventual and idempotent.
/// </summary>
internal sealed class PaymentFinalizationService(
    PaymentsDbContext paymentsDb,
    IPaymentOutboxDispatcher outbox,
    IAuditLogger auditLogger,
    ILogger<PaymentFinalizationService> logger,
    MessagingSettings? messaging = null,
    IEventSerializer? serializer = null,
    OutboxWriter<PaymentsDbContext>? kafkaOutbox = null) : IPaymentFinalizationService
{
    /// <summary>Commits payment, ledger and independent outboxes together before invoking the legacy dispatcher.</summary>
    public async Task<PaymentFinalizationResult> FinalizeSuccessfulPaymentAsync(
        Guid intentId, string? transactionId, string? payload,
        PaymentFinalizationSource source, CancellationToken ct = default)
    {
        Guid? outboxMessageId = null;
        PaymentIntent? finalizedIntent = null;

        await using (var tx = await paymentsDb.Database.BeginTransactionAsync(ct))
        {
            var intent = await paymentsDb.PaymentIntents.FromSqlInterpolated(
                    $"SELECT * FROM payments.payment_intents WHERE id = {intentId} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (intent is null)
                return new(false, "01", "Payment intent not found");
            if (intent.Status == "SUCCEEDED")
            {
                await tx.CommitAsync(ct);
                return new(true, "00", "Confirm Success");
            }
            if (intent.Status is not ("CREATED" or "PENDING"))
                return new(false, "99", $"Payment intent cannot be finalized from {intent.Status}");

            var succeeded = intent.MarkSucceeded(transactionId, payload, source.ToString());
            if (succeeded.IsFailure)
                return new(false, "99", succeeded.Error.Message);

            var otherPending = await paymentsDb.PaymentIntents
                .Where(x => x.BookingId == intent.BookingId && x.Id != intent.Id &&
                    x.Status == "PENDING")
                .ToListAsync(ct);
            foreach (var other in otherPending) other.MarkSuperseded();

            if (!await paymentsDb.LedgerEntries.AnyAsync(x =>
                    x.BookingId == intent.BookingId && x.TransactionType == "ESCROW_LOCK", ct))
            {
                var ledger = LedgerEntry.Create(
                    "ESCROW_LOCK", "customer:escrow", "escrow:platform", intent.Amount,
                    intent.BookingId, intent.Id);
                if (ledger.IsFailure) return new(false, "99", ledger.Error.Message);
                paymentsDb.LedgerEntries.Add(ledger.Value);
            }

            var integrationEvent = new PaymentSucceeded(intent.BookingId, intent.Id, intent.Amount);
            var message = OutboxMessage.Create(integrationEvent);
            paymentsDb.OutboxMessages.Add(message);
            // Keep Booking confirmation on the existing MediatR outbox. Kafka has independent state.
            if (messaging is { Enabled: true, PaymentsEnabled: true })
                kafkaOutbox!.Add(serializer!.Create(new CareSitter.Messaging.Contracts.Events.PaymentSucceeded(
                    intent.BookingId, intent.Id, integrationEvent.OccurredOnUtc),
                    new EventMetadata(integrationEvent.EventId, integrationEvent.OccurredOnUtc,
                        messaging.Producer, intent.BookingId.ToString(), System.Diagnostics.Activity.Current?.TraceId.ToString())));
            outboxMessageId = message.Id;
            finalizedIntent = intent;

            await paymentsDb.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }

        try
        {
            await auditLogger.WriteAsync("PAYMENT_FINALIZED", "PaymentIntent", intentId,
                new { paymentStatus = "PENDING" },
                new
                {
                    paymentStatus = "SUCCEEDED",
                    finalizedIntent!.BookingId,
                    finalizedIntent.Amount,
                    source = source.ToString()
                }, ct);
        }
        catch (Exception exception)
        {
            logger.LogCritical(exception,
                "Payment {PaymentIntentId} finalized but its audit entry could not be persisted.",
                intentId);
        }

        await outbox.DispatchAsync(outboxMessageId!.Value, ct);
        return new(true, "00", "Confirm Success");
    }
}
