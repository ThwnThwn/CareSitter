using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Booking-owned boundary exposed to Payments. This adapter never reads or writes
/// another module's schema.
/// </summary>
internal sealed class BookingPaymentGateway(BookingDbContext db) : IBookingPaymentGateway
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

    public async Task<IReadOnlyDictionary<Guid, BookingPaymentSnapshot>> GetManualReviewBookingsAsync(
        IReadOnlyCollection<Guid> bookingIds, CancellationToken ct = default)
    {
        var bookings = await db.Bookings.AsNoTracking().Where(x =>
            bookingIds.Contains(x.Id) && x.Status == BookingStatus.NeedsManualReview)
            .ToListAsync(ct);
        return bookings.ToDictionary(x => x.Id, ToSnapshot);
    }

    public async Task<IReadOnlyList<Guid>> ListDuePaymentBookingIdsAsync(
        DateTimeOffset now, int batchSize, CancellationToken ct = default) =>
        await db.Bookings.AsNoTracking()
            .Where(x => (x.Status == BookingStatus.PendingPayment && x.PaymentDeadline <= now) ||
                x.Status == BookingStatus.PaymentReconciliationPending)
            .OrderBy(x => x.PaymentDeadline)
            .ThenBy(x => x.Id)
            .Select(x => x.Id)
            .Take(Math.Clamp(batchSize, 1, 500))
            .ToListAsync(ct);

    private static BookingPaymentSnapshot ToSnapshot(Domain.Booking booking) => new(
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
