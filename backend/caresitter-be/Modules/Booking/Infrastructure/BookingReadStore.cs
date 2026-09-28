using CareSitter.Modules.Booking.Application;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingReadStore(BookingDbContext db) : IBookingReadStore
{
    public async Task<BookingPage> GetPageAsync(
        BookingPageCriteria criteria, CancellationToken ct = default)
    {
        var query = db.Bookings.AsNoTracking();
        query = criteria.Audience switch
        {
            BookingReadAudience.Customer => query.Where(
                x => x.CustomerId == criteria.PrincipalId),
            BookingReadAudience.Caregiver => query.Where(
                x => x.CaregiverId == criteria.PrincipalId),
            BookingReadAudience.OfferInbox => query.Where(
                x => criteria.BookingIds!.Contains(x.Id)),
            _ => query
        };
        if (criteria.Status.HasValue)
            query = query.Where(x => x.Status == criteria.Status.Value);

        var total = await query.CountAsync(ct);
        query = criteria.Audience == BookingReadAudience.OfferInbox
            ? query.OrderBy(x => x.ScheduledStart)
            : query.OrderByDescending(x => x.ScheduledStart);
        var items = await query.Skip((criteria.Page - 1) * criteria.PageSize)
            .Take(criteria.PageSize).ToListAsync(ct);
        return new BookingPage(items, total);
    }

    public Task<Domain.Booking?> GetAsync(
        Guid bookingId, CancellationToken ct = default) =>
        db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == bookingId, ct);

    public async Task<IReadOnlyList<Domain.Booking>> GetManyAsync(
        IReadOnlyCollection<Guid> bookingIds, CancellationToken ct = default) =>
        await db.Bookings.AsNoTracking().Where(x => bookingIds.Contains(x.Id)).ToListAsync(ct);

    public Task<bool> HasActiveCaregiverAccessAsync(
        Guid bookingId, Guid caregiverId, DateTimeOffset now,
        CancellationToken ct = default) =>
        db.BookingAssignments.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId && x.CaregiverId == caregiverId &&
            (x.Status == "OFFERED" || x.Status == "SUGGESTED") &&
            x.ExpiresAt != null && x.ExpiresAt > now, ct);
}
