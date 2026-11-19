using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>Booking-owned eligibility read exposed to Promotion through Contracts.</summary>
internal sealed class PromotionBookingLookup(BookingDbContext db) : IPromotionBookingLookup
{
    public Task<bool> HasPaidBookingAsync(Guid customerId, CancellationToken ct = default) =>
        db.Bookings.AsNoTracking().AnyAsync(x =>
            x.CustomerId == customerId &&
            x.Status != BookingStatus.Draft &&
            x.Status != BookingStatus.PendingPayment &&
            x.Status != BookingStatus.PaymentReconciliationPending &&
            x.Status != BookingStatus.NeedsManualReview &&
            x.Status != BookingStatus.Cancelled &&
            x.Status != BookingStatus.MatchingFailed,
            ct);

    public async Task<bool> CanReleaseExpiredReservationAsync(Guid bookingId, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var key = BookingCreationIdempotencyStore.PromotionReservationLockKey(bookingId);
        var acquired = await db.Database.SqlQuery<bool>(
            $"SELECT pg_try_advisory_xact_lock(hashtextextended({key}, 0)) AS \"Value\"").SingleAsync(ct);
        if (!acquired) return false;

        // This statement sees a committed booking even if creation finished just before the lock.
        var status = await db.Bookings.Where(b => b.Id == bookingId)
            .Select(b => (BookingStatus?)b.Status).SingleOrDefaultAsync(ct);
        var canRelease = status is null || status == BookingStatus.Cancelled &&
            !await db.BookingSyncEvents.AnyAsync(e => e.BookingId == bookingId &&
                e.EventType == BookingSyncEventTypes.PaymentConfirmed, ct);
        await transaction.CommitAsync(ct);
        return canRelease;
    }
}
