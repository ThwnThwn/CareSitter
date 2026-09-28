using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Exposes only the booking facts Support needs to authorize a review.
/// </summary>
public sealed class ReviewBookingLookup(BookingDbContext db) : IReviewBookingLookup
{
    public Task<ReviewableBooking?> GetForReviewAsync(
        Guid bookingId,
        CancellationToken ct = default) =>
        db.Bookings.AsNoTracking()
            .Where(x => x.Id == bookingId)
            .Select(x => new ReviewableBooking(
                x.Id,
                x.CustomerId,
                x.CaregiverId,
                x.Status == BookingStatus.Completed))
            .SingleOrDefaultAsync(ct);
}
