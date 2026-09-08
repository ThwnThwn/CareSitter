using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Application;

/// <summary>
/// Implementation của IBookingMembershipChecker cho SignalR Hub.
/// Được đăng ký trong Booking module và resolve qua DI khi Hub cần verify quyền join group.
///
/// Query JOIN people.caregiver_profiles để đối chiếu user_id thay vì caregiver_profile_id,
/// vì booking.caregiver_id là caregiver_profiles.id (không phải users.id).
/// </summary>
public sealed class BookingMembershipReader : IBookingMembershipChecker
{
    private readonly BookingDbContext _db;

    public BookingMembershipReader(BookingDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Kiểm tra userId có phải là customer hoặc caregiver được assign của booking không.
    /// Dùng SQL raw với JOIN vào people.caregiver_profiles để đối chiếu user_id.
    /// </summary>
    public Task<bool> IsPartyToBookingAsync(Guid bookingId, Guid userId, CancellationToken ct = default)
        => _db.Database
               .SqlQueryRaw<int>(
                   """
                   SELECT 1 AS "Value"
                   FROM booking.bookings b
                   WHERE b.id = {0}
                     AND (
                       b.customer_id = {1}
                       OR EXISTS (
                         SELECT 1
                         FROM people.caregiver_profiles cp
                         WHERE cp.id = b.caregiver_id
                           AND cp.user_id = {1}
                       )
                     )
                   LIMIT 1
                   """, bookingId, userId)
               .AnyAsync(ct);
}
