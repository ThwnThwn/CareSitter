using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>
/// Payments-owned reconciliation use case invoked by the scheduler. Booking state
/// changes are delivered through the durable outbox.
/// </summary>
internal sealed class PaymentReconciliationJob(
    PaymentsDbContext db,
    IBookingPaymentGateway bookings,
    IVNPayService vnPay,
    IOptions<VNPayOptions> options,
    IPaymentFinalizationService finalizer,
    IPaymentOutboxDispatcher outbox,
    IClock clock,
    ILogger<PaymentReconciliationJob> logger) : IPaymentReconciliationJob
{
    public async Task ExecuteAsync(CancellationToken ct = default)
    {
        var now = clock.UtcNow;
        var bookingIds = await bookings.ListDuePaymentBookingIdsAsync(now, 100, ct);
        foreach (var bookingId in bookingIds)
            await ReconcileBookingAsync(bookingId, now, ct);
    }

    private async Task ReconcileBookingAsync(
        Guid bookingId, DateTimeOffset now, CancellationToken ct)
    {
        var succeeded = await db.PaymentIntents.AsNoTracking()
            .Where(x => x.BookingId == bookingId && x.Provider == "VNPAY" &&
                x.Status == "SUCCEEDED")
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);
        if (succeeded is not null)
        {
            var result = await finalizer.FinalizeSuccessfulPaymentAsync(
                succeeded.Id, succeeded.ProviderTransactionId, succeeded.ResponsePayload,
                PaymentFinalizationSource.ReconciliationJob, ct);
            if (!result.Succeeded)
                logger.LogWarning(
                    "Could not finalize successful VNPay intent {IntentId}: {Message}",
                    succeeded.Id, result.Message);
            return;
        }

        var intent = await db.PaymentIntents.AsNoTracking()
            .Where(x => x.BookingId == bookingId && x.Provider == "VNPAY" &&
                x.Status == "PENDING")
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);
        if (intent is null)
        {
            await EnqueueAndDispatchAsync(new PaymentExpired(
                bookingId, null, "AUTO_EXPIRED_PAYMENT_RECONCILED"), ct);
            return;
        }
        if (intent.NextReconciliationAt is { } next && next > now)
            return;

        await EnqueueAndDispatchAsync(
            new PaymentReconciliationStarted(bookingId, intent.Id), ct);

        VNPayQueryResult query;
        try
        {
            query = await vnPay.QueryTransactionAsync(intent, options.Value, ct);
        }
        catch (Exception exception)
        {
            query = new VNPayQueryResult(
                VNPayQueryState.Unknown, null, "NETWORK", null, "{}", exception.Message);
        }

        if (query.State == VNPayQueryState.Succeeded)
        {
            var result = await finalizer.FinalizeSuccessfulPaymentAsync(
                intent.Id, query.TransactionId, query.RawPayload,
                PaymentFinalizationSource.ReconciliationJob, ct);
            if (!result.Succeeded)
                logger.LogWarning(
                    "Could not finalize reconciled VNPay intent {IntentId}: {Message}",
                    intent.Id, result.Message);
            return;
        }

        db.ChangeTracker.Clear();
        Guid? messageId = null;
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var locked = await db.PaymentIntents.FromSqlInterpolated(
                    $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (locked is null || locked.Status != "PENDING")
            {
                await tx.CommitAsync(ct);
                return;
            }

            var error = query.Message ?? $"VNPay state: {query.State}";
            var reachedLimit = locked.ReconciliationAttempts + 1 >=
                    options.Value.MaxReconciliationAttempts ||
                now - (locked.ReconciliationStartedAt ?? now) >=
                    TimeSpan.FromMinutes(options.Value.ReconciliationWindowMinutes);
            DateTimeOffset? nextAttempt = reachedLimit
                ? null
                : now.AddMinutes(locked.ReconciliationAttempts switch { 0 => 1, 1 => 3, _ => 6 });
            var recorded = locked.RecordReconciliationAttempt(now, nextAttempt, error);
            if (recorded.IsFailure)
                return;

            IIntegrationEvent? integrationEvent = null;
            if (query.State is VNPayQueryState.Failed or VNPayQueryState.NotFound)
            {
                var closed = query.State == VNPayQueryState.NotFound
                    ? locked.MarkExpired(PaymentFinalizationSource.ReconciliationJob.ToString(),
                        query.RawPayload)
                    : locked.MarkFailed(query.RawPayload,
                        PaymentFinalizationSource.ReconciliationJob.ToString());
                if (closed.IsFailure) return;
                integrationEvent = new PaymentExpired(
                    bookingId, locked.Id, "AUTO_EXPIRED_PAYMENT_RECONCILED");
            }
            else if (reachedLimit)
            {
                locked.SetManualReviewReason(error);
                integrationEvent = new PaymentNeedsManualReview(bookingId, locked.Id, error);
            }

            if (integrationEvent is not null)
            {
                var message = OutboxMessage.Create(integrationEvent);
                db.OutboxMessages.Add(message);
                messageId = message.Id;
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }

        if (messageId is { } id)
            await outbox.DispatchAsync(id, ct);
    }

    private async Task EnqueueAndDispatchAsync(
        IIntegrationEvent integrationEvent, CancellationToken ct)
    {
        var message = OutboxMessage.Create(integrationEvent);
        db.OutboxMessages.Add(message);
        await db.SaveChangesAsync(ct);
        await outbox.DispatchAsync(message.Id, ct);
    }
}
