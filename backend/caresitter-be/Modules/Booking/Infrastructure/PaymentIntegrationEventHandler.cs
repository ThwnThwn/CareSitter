using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Idempotent consumer for Payments events. Only Booking-owned tables are changed here;
/// a failed delivery remains in the Payments outbox and is retried.
/// </summary>
internal sealed class PaymentIntegrationEventHandler(
    BookingDbContext db,
    IServiceChecklistCatalog catalog,
    IBookingSyncService bookingSync,
    IBookingPostCommitService postCommit,
    IMatchingService matching,
    IWalletService wallet,
    IPromotionService promotions,
    IClock clock,
    ILogger<PaymentIntegrationEventHandler> logger) :
    INotificationHandler<PaymentSucceeded>,
    INotificationHandler<PaymentFailed>,
    INotificationHandler<PaymentReviewRejected>,
    INotificationHandler<PaymentReconciliationStarted>,
    INotificationHandler<PaymentExpired>,
    INotificationHandler<PaymentNeedsManualReview>
{
    public async Task Handle(PaymentSucceeded notification, CancellationToken ct)
    {
        var serviceTypeId = await db.Bookings.AsNoTracking()
            .Where(x => x.Id == notification.BookingId)
            .Select(x => (Guid?)x.ServiceTypeId)
            .SingleOrDefaultAsync(ct);
        if (serviceTypeId is null)
            throw new InvalidOperationException($"Booking {notification.BookingId} was not found.");

        var allowAdHocTasks = await catalog.GetAllowAdHocTasksAsync(serviceTypeId.Value, ct) ?? false;

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(notification.BookingId, ct)
            ?? throw new InvalidOperationException($"Booking {notification.BookingId} was not found.");
        // A payment URL may have been issued before an unpaid booking was repriced.
        // Leave the durable outbox message unprocessed for reconciliation instead of
        // confirming care backed by a different amount of money.
        if (notification.Amount != booking.CustomerPayableAmount)
            throw new InvalidOperationException(
                $"Payment amount {notification.Amount} does not match booking {booking.Id} payable amount {booking.CustomerPayableAmount}.");

        // The sync event is persisted in the same transaction as confirmation and
        // remains a receipt even after the booking advances to another state.
        var paymentAlreadyApplied = booking.Status == BookingStatus.Confirmed ||
            await db.BookingSyncEvents.AnyAsync(x => x.BookingId == booking.Id &&
                x.EventType == BookingSyncEventTypes.PaymentConfirmed, ct);
        if (paymentAlreadyApplied)
        {
            await tx.CommitAsync(ct);
            if (booking.Status is not (BookingStatus.Cancelled or BookingStatus.Refunded))
                await FinalizePromotionAsync(booking, ct);
            return;
        }
        if (booking.Status is not (BookingStatus.PendingPayment or
            BookingStatus.PaymentReconciliationPending or BookingStatus.NeedsManualReview))
            throw new InvalidOperationException(
                $"Booking {booking.Id} cannot accept payment from state {booking.Status}.");

        var confirmation = booking.ConfirmPayment();
        if (confirmation.IsFailure)
            throw new InvalidOperationException(confirmation.Error.Message);

        booking.SnapshotChecklistPolicy(allowAdHocTasks);
        if (!await db.CareTasks.AnyAsync(x => x.BookingId == booking.Id, ct))
        {
            var templates = await db.PackageTaskTemplates.AsNoTracking()
                .Where(x => x.ServiceTypeId == booking.ServiceTypeId && x.IsActive)
                .OrderBy(x => x.SortOrder)
                .ToListAsync(ct);
            db.CareTasks.AddRange(templates.Select(template => CareTask.Create(
                booking.Id, template.Name, template.Description, template.IsRequired,
                template.RequiresPhoto, template.SortOrder, "PACKAGE", templateId: template.Id)));
        }

        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.PaymentConfirmed);
        var hold = await db.CaregiverSlotHolds.SingleOrDefaultAsync(
            x => x.BookingId == booking.Id && x.Status == "HELD", ct);
        hold?.Commit();
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        await FinalizePromotionAsync(booking, ct);

        await postCommit.RunAsync("caregiver matching", () =>
            matching.OfferTopCandidatesAsync(booking.Id, ct));
    }

    public async Task Handle(PaymentFailed notification, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(notification.BookingId, ct);
        if (booking is null)
        {
            logger.LogWarning("Payment failure references missing booking {BookingId}.",
                notification.BookingId);
            await tx.CommitAsync(ct);
            return;
        }

        var holds = await db.CaregiverSlotHolds
            .Where(x => x.BookingId == booking.Id && x.Status == "HELD")
            .ToListAsync(ct);
        foreach (var hold in holds) hold.Release();
        if (holds.Count > 0) await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    public async Task Handle(PaymentReviewRejected notification, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(notification.BookingId, ct)
            ?? throw new InvalidOperationException($"Booking {notification.BookingId} was not found.");
        if (booking.Status == BookingStatus.Cancelled)
        {
            await tx.CommitAsync(ct);
            await promotions.ReleaseAsync(booking.Id, booking.CustomerId,
                "PAYMENT_REJECTED", ct);
            return;
        }
        if (booking.Status != BookingStatus.NeedsManualReview)
            throw new InvalidOperationException(
                $"Booking {booking.Id} cannot reject payment from state {booking.Status}.");

        var cancelled = booking.Cancel(
            booking.CustomerId, "ADMIN", $"PAYMENT_MANUAL_REJECTED: {notification.Reason}",
            clock.UtcNow);
        if (cancelled.IsFailure)
            throw new InvalidOperationException(cancelled.Error.Message);

        var holds = await db.CaregiverSlotHolds
            .Where(x => x.BookingId == booking.Id && x.Status == "HELD")
            .ToListAsync(ct);
        foreach (var hold in holds) hold.Release();
        bookingSync.WriteSyncEvent(booking, "PAYMENT_MANUAL_REJECTED");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        await promotions.ReleaseAsync(booking.Id, booking.CustomerId,
            "PAYMENT_REJECTED", ct);

    }

    public async Task Handle(PaymentReconciliationStarted notification, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(notification.BookingId, ct)
            ?? throw new InvalidOperationException($"Booking {notification.BookingId} was not found.");
        if (booking.Status != BookingStatus.PendingPayment)
        {
            await tx.CommitAsync(ct);
            return;
        }

        var result = booking.BeginPaymentReconciliation();
        if (result.IsFailure) throw new InvalidOperationException(result.Error.Message);
        bookingSync.WriteSyncEvent(booking, "PAYMENT_RECONCILIATION_STARTED");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    public async Task Handle(PaymentExpired notification, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(notification.BookingId, ct)
            ?? throw new InvalidOperationException($"Booking {notification.BookingId} was not found.");
        if (booking.Status == BookingStatus.Cancelled)
        {
            await tx.CommitAsync(ct);
            await promotions.ReleaseAsync(booking.Id, booking.CustomerId,
                "PAYMENT_EXPIRED", ct);
            return;
        }
        if (booking.Status is not (BookingStatus.PendingPayment or
            BookingStatus.PaymentReconciliationPending))
            throw new InvalidOperationException(
                $"Booking {booking.Id} cannot expire payment from state {booking.Status}.");

        var cancelled = booking.Cancel(
            booking.CustomerId, "SYSTEM", notification.Reason, clock.UtcNow);
        if (cancelled.IsFailure) throw new InvalidOperationException(cancelled.Error.Message);
        var holds = await db.CaregiverSlotHolds
            .Where(x => x.BookingId == booking.Id && x.Status == "HELD")
            .ToListAsync(ct);
        foreach (var hold in holds) hold.Release();
        bookingSync.WriteSyncEvent(booking, "PAYMENT_EXPIRED");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        await promotions.ReleaseAsync(booking.Id, booking.CustomerId,
            "PAYMENT_EXPIRED", ct);
    }

    public async Task Handle(PaymentNeedsManualReview notification, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(notification.BookingId, ct)
            ?? throw new InvalidOperationException($"Booking {notification.BookingId} was not found.");
        if (booking.Status == BookingStatus.NeedsManualReview)
        {
            await tx.CommitAsync(ct);
            return;
        }
        if (booking.Status == BookingStatus.PendingPayment)
        {
            var started = booking.BeginPaymentReconciliation();
            if (started.IsFailure) throw new InvalidOperationException(started.Error.Message);
        }
        if (booking.Status != BookingStatus.PaymentReconciliationPending)
            throw new InvalidOperationException(
                $"Booking {booking.Id} cannot enter manual review from state {booking.Status}.");

        var reviewed = booking.MarkPaymentNeedsManualReview();
        if (reviewed.IsFailure) throw new InvalidOperationException(reviewed.Error.Message);
        bookingSync.WriteSyncEvent(booking, "PAYMENT_NEEDS_MANUAL_REVIEW");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    private Task<Domain.Booking?> LockBookingAsync(Guid bookingId, CancellationToken ct) =>
        db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);

    private async Task FinalizePromotionAsync(Domain.Booking booking,
        CancellationToken ct)
    {
        if (booking.PromotionId is null) return;
        var subsidy = await wallet.RecordPromotionSubsidyAsync(
            booking.Id, booking.PromotionSubsidyAmount, ct);
        if (subsidy.IsFailure)
            throw new InvalidOperationException(subsidy.Error.Message);
        var redemption = await promotions.RedeemAsync(
            booking.Id, booking.CustomerId, ct);
        if (redemption.IsFailure)
            throw new InvalidOperationException(redemption.Error.Message);
    }
}
