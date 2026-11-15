using System.Runtime.CompilerServices;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingCheckoutStore(BookingDbContext db,
    IDisputeLookupService disputeLookup, IBookingSyncService sync,
    ILogger<BookingCheckoutStore> logger) : IBookingCheckoutStore
{
    public async Task<IReadOnlyList<BookingEntity>> RecordLateCheckinsAsync(DateTimeOffset warningCutoff, CancellationToken ct = default)
    {
        var changed = new List<BookingEntity>();

        var lateBookings = await db.Bookings
            .Where(b =>
                (b.Status == BookingStatus.CaregiverAccepted || b.Status == BookingStatus.CaregiverEnRoute)
                && b.ScheduledStart <= warningCutoff)
            .ToListAsync(ct);

        foreach (var booking in lateBookings)
        {
            bool alreadyWarned = await db.TimelineEvents.AnyAsync(e =>
                e.BookingId == booking.Id && e.EventType == "LATE_CHECKIN", ct);

            if (alreadyWarned) continue;

            logger.LogWarning(
                "[BookingJobs] Late check-in for booking {Id} (scheduled {Start})",
                booking.Id, booking.ScheduledStart);

            var warnEvt = CareTimelineEvent.Create(
                booking.Id, booking.CaregiverId,
                eventType: "LATE_CHECKIN",
                title: "Caregiver chưa check-in đúng giờ",
                note: $"Ca bắt đầu lúc {booking.ScheduledStart:HH:mm} nhưng chưa check-in.",
                source: "SYSTEM");

            db.TimelineEvents.Add(warnEvt);

            changed.Add(booking);
        }

        if (lateBookings.Count > 0)
            await db.SaveChangesAsync(ct);
        return changed;
    }

    public async IAsyncEnumerable<BookingJobChange> RequestExpiredCheckoutsAsync(DateTimeOffset cutoff, [EnumeratorCancellation] CancellationToken ct = default)
    {

        var expiredShifts = await db.Bookings
            .Where(b => b.Status == BookingStatus.InProgress && b.ScheduledEnd <= cutoff)
            .ToListAsync(ct);

        if (expiredShifts.Count == 0) yield break;

        logger.LogInformation(
            "[BookingJobs] AutoRequestCheckout: found {Count} shifts to move to review", expiredShifts.Count);

        foreach (var booking in expiredShifts)
        {
            var oldStatus = BookingStatusPresenter.ToApi(booking.Status);
            var requestedAt = DateTimeOffset.UtcNow;
            if (await db.CareTasks.AnyAsync(t => t.BookingId == booking.Id &&
                    (t.Status == "PENDING" || (t.IsRequired && t.Status == "SKIPPED")), ct))
                booking.MarkNeedsReview();
            var result = booking.RequestSystemTimeoutCheckout(requestedAt);
            if (result.IsFailure)
            {
                logger.LogWarning(
                    "[BookingJobs] Cannot move booking {Id} to checkout review: {Error}",
                    booking.Id, result.Error.Message);
                continue;
            }

            var evt = CareTimelineEvent.Create(
                booking.Id,
                booking.CaregiverId,
                eventType: "AUTO_CHECKOUT",
                title: "Ca chuyển sang chờ xác nhận tự động",
                note: "session_timeout_auto_checkout: ca đã quá giờ dự kiến, hệ thống chuyển sang chờ gia đình xác nhận.",
                source: "SYSTEM",
                metadata: "{\"reason\":\"session_timeout_auto_checkout\"}");
            db.TimelineEvents.Add(evt);
            sync.WriteSyncEvent(booking, BookingSyncEventTypes.CheckoutRequested);
            await db.SaveChangesAsync(ct);

            yield return new(booking, oldStatus, requestedAt);
        }

        await db.SaveChangesAsync(ct);
        logger.LogInformation("[BookingJobs] Moved {Count} expired shifts to checkout review", expiredShifts.Count);
    }

    public async IAsyncEnumerable<BookingJobChange> ConfirmPendingCheckoutsAsync(DateTimeOffset cutoff, [EnumeratorCancellation] CancellationToken ct = default)
    {

        var candidateIds = await db.Bookings.AsNoTracking()
            .Where(b => b.Status == BookingStatus.CheckoutPendingReview
                && !b.NeedsReview
                && !db.CareTasks.Any(t => t.BookingId == b.Id &&
                    (t.Status == "PENDING" || (t.IsRequired && t.Status == "SKIPPED")))
                && b.CheckoutPendingReviewAt != null
                && b.CheckoutPendingReviewAt <= cutoff)
            .Select(b => b.Id)
            .ToListAsync(ct);

        if (candidateIds.Count == 0) yield break;

        foreach (var bookingId in candidateIds)
        {
            if (await disputeLookup.HasOpenDisputeAsync(bookingId, ct))
                continue;

            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var booking = await db.Bookings.SingleOrDefaultAsync(b =>
                b.Id == bookingId && b.Status == BookingStatus.CheckoutPendingReview
                && !b.NeedsReview
                && !db.CareTasks.Any(t => t.BookingId == b.Id &&
                    (t.Status == "PENDING" || (t.IsRequired && t.Status == "SKIPPED"))), ct);
            if (booking is null)
            {
                await tx.RollbackAsync(ct);
                continue;
            }
            if (booking.CaregiverId is not { } caregiverId)
            {
                await tx.RollbackAsync(ct);
                continue;
            }

            if (await disputeLookup.HasOpenDisputeAsync(booking.Id, ct))
            {
                await tx.RollbackAsync(ct);
                continue;
            }

            var oldStatus = BookingStatusPresenter.ToApi(booking.Status);
            var result = booking.Complete();
            if (result.IsFailure)
            {
                await tx.RollbackAsync(ct);
                logger.LogWarning(
                    "[BookingJobs] Cannot auto-confirm checkout for booking {Id}: {Error}",
                    booking.Id, result.Error.Message);
                continue;
            }

            if (await disputeLookup.HasOpenDisputeAsync(booking.Id, ct))
            {
                await tx.RollbackAsync(ct);
                continue;
            }

            db.TimelineEvents.Add(CareTimelineEvent.Create(
                booking.Id,
                caregiverId,
                eventType: "CHECKOUT",
                title: "Ca tự động hoàn tất",
                note: $"Auto-confirm sau {BookingLifecyclePolicy.AutoConfirmCheckoutHours}h chờ gia đình xác nhận, không có dispute mở.",
                source: "SYSTEM",
                metadata: "{\"reason\":\"auto_confirm_after_customer_timeout\"}"));

            sync.WriteSyncEvent(booking, BookingSyncEventTypes.Completed);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            yield return new(booking, oldStatus, DateTimeOffset.UtcNow);
        }
    }
}
