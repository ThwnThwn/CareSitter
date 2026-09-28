using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.EntityFrameworkCore;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.ApiHost.Persistence;

internal sealed class BookingPaymentGateway(
    BookingDbContext db,
    IBookingSyncService bookingSync,
    IClock clock) : IBookingPaymentGateway
{
    public async Task<BookingPaymentSnapshot?> GetForCustomerAsync(
        Guid bookingId, Guid customerId, CancellationToken ct = default)
    {
        var booking = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(
            x => x.Id == bookingId && x.CustomerId == customerId, ct);
        return booking is null ? null : ToSnapshot(booking);
    }

    public async Task<BookingPaymentHoldResult> EnsureSlotHoldAsync(
        Guid bookingId, int reconciliationWindowMinutes, CancellationToken ct = default)
    {
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null)
            return new(BookingPaymentMutationStatus.BookingNotFound);
        if (booking.Status != BookingStatus.PendingPayment)
            return new(BookingPaymentMutationStatus.BookingStateChanged);
        if (booking.CaregiverId is not { } caregiverId)
            return new(BookingPaymentMutationStatus.Succeeded);

        var holdUntil = booking.PaymentDeadline.AddMinutes(
            Math.Clamp(reconciliationWindowMinutes, 1, 60));
        var existing = await db.CaregiverSlotHolds.SingleOrDefaultAsync(
            x => x.BookingId == booking.Id && x.Status == "HELD", ct);
        if (existing is not null && existing.CaregiverId == caregiverId)
        {
            existing.ExtendUntil(holdUntil);
            await db.SaveChangesAsync(ct);
            return new(BookingPaymentMutationStatus.Succeeded);
        }

        if (existing is not null)
        {
            existing.Release();
            await db.SaveChangesAsync(ct);
        }

        var created = CaregiverSlotHold.Create(
            booking.Id, caregiverId, booking.ScheduledStart, booking.ScheduledEnd, holdUntil);
        if (created.IsFailure)
            return new(BookingPaymentMutationStatus.CaregiverSlotHeld);
        db.CaregiverSlotHolds.Add(created.Value);
        try
        {
            await db.SaveChangesAsync(ct);
            return new(BookingPaymentMutationStatus.Succeeded, created.Value.Id);
        }
        catch (DbUpdateException)
        {
            return new(BookingPaymentMutationStatus.CaregiverSlotHeld);
        }
    }

    public async Task ReleaseSlotHoldAsync(
        Guid bookingId, Guid holdId, CancellationToken ct = default)
    {
        var hold = await db.CaregiverSlotHolds.SingleOrDefaultAsync(
            x => x.Id == holdId && x.BookingId == bookingId && x.Status == "HELD", ct);
        if (hold is null) return;
        hold.Release();
        await db.SaveChangesAsync(ct);
    }

    public async Task<BookingPaymentMutationStatus> ClosePendingIntentAsync(
        Guid bookingId, Guid intentId, string closedStatus, string payload,
        string source, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(bookingId, ct);
        if (booking is null) return BookingPaymentMutationStatus.BookingNotFound;
        if (booking.Status != BookingStatus.PendingPayment)
            return BookingPaymentMutationStatus.BookingStateChanged;

        var updated = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = {{closedStatus}}, response_payload = CAST({{payload}} AS jsonb),
                finalized_source = {{source}}, next_reconciliation_at = NULL,
                updated_at = now()
            WHERE id = {{intentId}} AND status = 'PENDING'
            """, ct);
        if (updated == 0) return BookingPaymentMutationStatus.IntentStateChanged;
        await tx.CommitAsync(ct);
        return BookingPaymentMutationStatus.Succeeded;
    }

    public async Task<BookingPaymentFinalizationOutcome> FinalizeAsync(
        BookingPaymentFinalization request, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(request.BookingId, ct);
        if (booking is null)
            return new(false, false, "01", "Booking not found");
        if (booking.Status == BookingStatus.Confirmed)
        {
            await tx.CommitAsync(ct);
            return new(true, false, "00", "Already finalized", ToSnapshot(booking));
        }
        if (booking.Status is not (BookingStatus.PendingPayment or
            BookingStatus.PaymentReconciliationPending or BookingStatus.NeedsManualReview))
            return new(false, false, "99",
                $"Booking cannot be finalized from {booking.Status}");

        var updated = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'SUCCEEDED',
                provider_transaction_id = COALESCE({{request.ProviderTransactionId}}, provider_transaction_id),
                response_payload = CASE WHEN {{request.Payload}} IS NULL
                    THEN response_payload ELSE CAST({{request.Payload}} AS jsonb) END,
                finalized_source = {{request.Source}},
                next_reconciliation_at = NULL,
                manual_review_reason = NULL,
                updated_at = now()
            WHERE id = {{request.IntentId}} AND status IN ('CREATED', 'PENDING', 'SUCCEEDED')
            """, ct);
        if (updated == 0)
            return new(false, false, "99",
                $"Payment intent cannot be finalized from {request.IntentStatus}");

        await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'SUPERSEDED', next_reconciliation_at = NULL, updated_at = now()
            WHERE booking_id = {{booking.Id}} AND id <> {{request.IntentId}} AND status = 'PENDING'
            """, ct);
        await db.Database.ExecuteSqlInterpolatedAsync($$"""
            INSERT INTO payments.ledger_entries (
                id, booking_id, payment_intent_id, transaction_type,
                debit_account, credit_account, amount, currency, status, created_at)
            VALUES (
                {{request.LedgerEntryId}}, {{booking.Id}}, {{request.IntentId}}, 'ESCROW_LOCK',
                'customer:escrow', 'escrow:platform', {{request.Amount}}, 'VND', 'PENDING', now())
            ON CONFLICT DO NOTHING
            """, ct);

        var confirmation = booking.ConfirmPayment();
        if (confirmation.IsFailure)
            return new(false, false, "99", confirmation.Error.Message);
        var allowAdHocTasks = await db.Database.SqlQueryRaw<bool>(
            "SELECT allow_ad_hoc_tasks AS \"Value\" FROM catalog.service_types WHERE id = {0}",
            booking.ServiceTypeId).SingleOrDefaultAsync(ct);
        booking.SnapshotChecklistPolicy(allowAdHocTasks);
        if (!await db.CareTasks.AnyAsync(x => x.BookingId == booking.Id, ct))
        {
            var templates = await db.PackageTaskTemplates.AsNoTracking()
                .Where(x => x.ServiceTypeId == booking.ServiceTypeId && x.IsActive)
                .OrderBy(x => x.SortOrder).ToListAsync(ct);
            db.CareTasks.AddRange(templates.Select(template => CareTask.Create(
                booking.Id, template.Name, template.Description, template.IsRequired,
                template.RequiresPhoto, template.SortOrder, "PACKAGE",
                templateId: template.Id)));
        }

        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.PaymentConfirmed);
        var hold = await db.CaregiverSlotHolds.SingleOrDefaultAsync(
            x => x.BookingId == booking.Id && x.Status == "HELD", ct);
        hold?.Commit();
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(true, true, "00", "Confirm Success", ToSnapshot(booking));
    }

    public Task<long> GetCurrentSyncCursorAsync(
        Guid customerId, CancellationToken ct = default) =>
        bookingSync.GetCurrentCursorAsync(customerId, ct);

    public async Task<BookingPaymentSnapshot?> RecordFailedAttemptAsync(
        Guid bookingId, Guid intentId, string payload, string source,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(bookingId, ct);
        if (booking is null || booking.Status is not
            (BookingStatus.PendingPayment or BookingStatus.PaymentReconciliationPending))
            return null;

        var updated = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'FAILED', response_payload = CAST({{payload}} AS jsonb),
                finalized_source = {{source}}, next_reconciliation_at = NULL,
                updated_at = now()
            WHERE id = {{intentId}} AND status IN ('CREATED', 'PENDING')
            """, ct);
        if (updated == 0) return null;

        var hold = await db.CaregiverSlotHolds.SingleOrDefaultAsync(
            x => x.BookingId == booking.Id && x.Status == "HELD", ct);
        hold?.Release();
        if (hold is not null) await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ToSnapshot(booking);
    }

    public async Task<IReadOnlyDictionary<Guid, BookingPaymentSnapshot>> GetManualReviewBookingsAsync(
        IReadOnlyCollection<Guid> bookingIds, CancellationToken ct = default)
    {
        var bookings = await db.Bookings.AsNoTracking().Where(x =>
            bookingIds.Contains(x.Id) && x.Status == BookingStatus.NeedsManualReview)
            .ToListAsync(ct);
        return bookings.ToDictionary(x => x.Id, ToSnapshot);
    }

    public async Task<BookingPaymentRejectionOutcome> RejectManualReviewAsync(
        Guid bookingId, Guid intentId, string reason, string payload,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await LockBookingAsync(bookingId, ct);
        if (booking is null)
            return new(BookingPaymentMutationStatus.BookingNotFound);
        if (booking.Status != BookingStatus.NeedsManualReview)
            return new(BookingPaymentMutationStatus.BookingStateChanged);

        var updated = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'FAILED', response_payload = CAST({{payload}} AS jsonb),
                manual_review_reason = {{reason.Trim()}}, finalized_source = 'AdminManual',
                next_reconciliation_at = NULL, updated_at = now()
            WHERE id = {{intentId}} AND status = 'PENDING'
            """, ct);
        if (updated == 0)
            return new(BookingPaymentMutationStatus.IntentStateChanged);
        await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = 'SUPERSEDED', next_reconciliation_at = NULL, updated_at = now()
            WHERE booking_id = {{booking.Id}} AND id <> {{intentId}} AND status = 'PENDING'
            """, ct);

        var cancelled = booking.Cancel(
            booking.CustomerId, "ADMIN", $"PAYMENT_MANUAL_REJECTED: {reason}", clock.UtcNow);
        if (cancelled.IsFailure)
            return new(BookingPaymentMutationStatus.BookingStateChanged);
        var holds = await db.CaregiverSlotHolds.Where(
            x => x.BookingId == booking.Id && x.Status == "HELD").ToListAsync(ct);
        foreach (var hold in holds) hold.Release();
        bookingSync.WriteSyncEvent(booking, "PAYMENT_MANUAL_REJECTED");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(BookingPaymentMutationStatus.Succeeded, ToSnapshot(booking));
    }

    private Task<BookingEntity?> LockBookingAsync(Guid bookingId, CancellationToken ct) =>
        db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);

    private static BookingPaymentSnapshot ToSnapshot(BookingEntity booking) => new(
        booking.Id, booking.CustomerId, booking.CaregiverId, booking.ServiceTypeId,
        booking.ScheduledStart, booking.ScheduledEnd, booking.PaymentDeadline,
        booking.EscrowAmount, booking.SyncVersion, booking.Status switch
        {
            BookingStatus.PendingPayment => BookingPaymentState.PendingPayment,
            BookingStatus.PaymentReconciliationPending =>
                BookingPaymentState.PaymentReconciliationPending,
            BookingStatus.NeedsManualReview => BookingPaymentState.NeedsManualReview,
            BookingStatus.Confirmed => BookingPaymentState.Confirmed,
            _ => BookingPaymentState.Other
        });
}
