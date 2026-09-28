using System.Text.Json;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Infrastructure.Outbox;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Payments.Infrastructure;

internal interface IPaymentOutboxDispatcher
{
    Task DispatchAsync(Guid messageId, CancellationToken ct = default);
    Task<int> DispatchPendingAsync(int batchSize = 20, CancellationToken ct = default);
}

internal sealed class PaymentOutboxDispatcher(
    PaymentsDbContext db,
    IPublisher publisher,
    ILogger<PaymentOutboxDispatcher> logger) : IPaymentOutboxDispatcher
{
    public async Task DispatchAsync(Guid messageId, CancellationToken ct = default)
    {
        var message = await db.OutboxMessages.SingleOrDefaultAsync(
            x => x.Id == messageId && x.ProcessedOnUtc == null, ct);
        if (message is not null)
            await DispatchMessageAsync(message, ct);
    }

    public async Task<int> DispatchPendingAsync(
        int batchSize = 20, CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        var messages = await db.OutboxMessages
            .Where(x => x.ProcessedOnUtc == null &&
                (x.NextAttemptOnUtc == null || x.NextAttemptOnUtc <= now))
            .OrderBy(x => x.OccurredOnUtc)
            .Take(Math.Clamp(batchSize, 1, 100))
            .ToListAsync(ct);

        foreach (var message in messages)
            await DispatchMessageAsync(message, ct);

        return messages.Count;
    }

    private async Task DispatchMessageAsync(OutboxMessage message, CancellationToken ct)
    {
        try
        {
            await publisher.Publish(Deserialize(message), ct);
            message.MarkProcessed(DateTimeOffset.UtcNow);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            message.MarkFailed(exception.ToString(), DateTimeOffset.UtcNow);
            logger.LogError(exception,
                "Could not dispatch Payments outbox message {OutboxMessageId} ({OutboxMessageType}).",
                message.Id, message.Type);
        }

        await db.SaveChangesAsync(ct);
    }

    private static IIntegrationEvent Deserialize(OutboxMessage message) => message.Type switch
    {
        var type when type == typeof(PaymentSucceeded).FullName =>
            Deserialize<PaymentSucceeded>(message),
        var type when type == typeof(PaymentFailed).FullName =>
            Deserialize<PaymentFailed>(message),
        var type when type == typeof(PaymentReviewRejected).FullName =>
            Deserialize<PaymentReviewRejected>(message),
        var type when type == typeof(PaymentReconciliationStarted).FullName =>
            Deserialize<PaymentReconciliationStarted>(message),
        var type when type == typeof(PaymentExpired).FullName =>
            Deserialize<PaymentExpired>(message),
        var type when type == typeof(PaymentNeedsManualReview).FullName =>
            Deserialize<PaymentNeedsManualReview>(message),
        _ => throw new InvalidOperationException(
            $"Unsupported Payments outbox message type '{message.Type}'.")
    };

    private static T Deserialize<T>(OutboxMessage message) where T : IIntegrationEvent =>
        JsonSerializer.Deserialize<T>(message.Payload)
        ?? throw new InvalidOperationException(
            $"Outbox message {message.Id} has an invalid payload.");
}
