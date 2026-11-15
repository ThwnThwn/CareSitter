using CareSitter.Contracts.Services;
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
}
