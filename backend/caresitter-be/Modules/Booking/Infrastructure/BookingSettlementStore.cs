using System.Runtime.CompilerServices;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingSettlementStore(BookingDbContext db,
    IBookingSyncService sync, ILogger<BookingSettlementStore> logger) : IBookingSettlementStore
{
    public async IAsyncEnumerable<BookingEntity> UnmatchedBookingsAsync([EnumeratorCancellation] CancellationToken ct = default)
    {
        var ids = await db.Bookings.AsNoTracking().Where(x => x.Status == BookingStatus.MatchingFailed)
            .OrderBy(x => x.UpdatedAt).Select(x => x.Id).Take(100).ToListAsync(ct);
        foreach (var id in ids)
        {
            // Re-read each candidate before crediting: a snapshot of the whole
            // batch can be stale by the time the wallet transaction starts.
            var booking = await db.Bookings.AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == id && x.Status == BookingStatus.MatchingFailed, ct);
            if (booking is not null) yield return booking;
        }
    }

    public async Task<BookingEntity?> MarkRefundedAsync(Guid bookingId, CancellationToken ct = default)
    {
        // Payments must commit before this lock: its ledger FK can otherwise deadlock with Booking.
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE").SingleOrDefaultAsync(ct);
        if (booking is null || booking.Status != BookingStatus.MatchingFailed)
        {
            await tx.CommitAsync(ct);
            return null;
        }
        var transitioned = booking.TransitionTo(BookingStatus.Refunded);
        if (transitioned.IsFailure)
        {
            logger.LogWarning("Could not mark unmatched booking {BookingId} refunded: {Reason}", bookingId, transitioned.Error.Message);
            await tx.RollbackAsync(ct);
            return null;
        }
        sync.WriteSyncEvent(booking, "REFUNDED_NO_CAREGIVER");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return booking;
    }

    public async Task<IReadOnlyList<BookingEntity>> UnreleasedSettlementsAsync(CancellationToken ct = default) =>
        await db.Bookings.AsNoTracking()
            .Where(x => x.Status == BookingStatus.Completed && x.SettlementReleasedAt == null &&
                x.ActualEnd != null && x.CaregiverId != null)
            .OrderBy(x => x.ActualEnd).Take(100).ToListAsync(ct);

    public async Task MarkSettlementReleasedAsync(Guid bookingId, DateTimeOffset now, CancellationToken ct = default)
    {
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null || booking.SettlementReleasedAt is not null) return;
        var marked = booking.MarkSettlementReleased(now);
        if (marked.IsFailure)
        {
            logger.LogWarning("Settlement released but booking {BookingId} could not be stamped: {Reason}", bookingId, marked.Error.Message);
            return;
        }
        await db.SaveChangesAsync(ct);
    }
}
