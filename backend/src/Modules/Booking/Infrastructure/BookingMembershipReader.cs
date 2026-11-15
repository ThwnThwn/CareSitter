using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Booking-owned SignalR membership check. Cross-module caregiver identity lookup
/// goes through the People contract instead of joining its schema.
/// </summary>
public sealed class BookingMembershipReader(
    BookingDbContext db,
    IPeopleLookupService people) : IBookingMembershipChecker, IBookingPartyAccess, IBookingReportAccess
{
    public Task<bool> IsCustomerAsync(Guid bookingId, Guid userId, CancellationToken ct = default) =>
        db.Bookings.AsNoTracking().AnyAsync(x => x.Id == bookingId && x.CustomerId == userId, ct);

    public Task<bool> IsPartyAsync(Guid bookingId, Guid userId, CancellationToken ct = default) =>
        IsPartyToBookingAsync(bookingId, userId, ct);
    public async Task<bool> IsPartyToBookingAsync(
        Guid bookingId, Guid userId, CancellationToken ct = default)
    {
        var party = await db.Bookings.AsNoTracking()
            .Where(x => x.Id == bookingId)
            .Select(x => new { x.CustomerId, x.CaregiverId })
            .SingleOrDefaultAsync(ct);
        if (party is null) return false;
        if (party.CustomerId == userId) return true;
        return party.CaregiverId is { } caregiverId &&
            await people.IsCaregiverForBookingAsync(caregiverId, userId, ct);
    }
}
