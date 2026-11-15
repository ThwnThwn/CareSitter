using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingMealStore(BookingDbContext db) : IBookingMealStore
{
    public async Task<Result<T>> InBookingScopeAsync<T>(Guid bookingId,
        Func<Domain.Booking, IBookingMealSession, Task<Result<T>>> action, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Cùng khóa hàng với các thay đổi booking: quyền caregiver, chia sẻ thực đơn,
        // ghi nhận bữa ăn và idempotency được kiểm tra trên một trạng thái đã khóa.
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .AsNoTracking().SingleOrDefaultAsync(ct);
        if (booking is null) return BookingErrors.NotFound();
        var result = await action(booking, new Session(db, bookingId));
        if (result.IsFailure) return result.Error;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return result;
    }

    private sealed class Session(BookingDbContext db, Guid bookingId) : IBookingMealSession
    {
        public async Task<IReadOnlyList<BookingMealPlan>> PlansAsync(CancellationToken ct) =>
            await db.BookingMealPlans.Where(x => x.BookingId == bookingId).OrderBy(x => x.PlannedDate).ToListAsync(ct);
        public async Task<IReadOnlyList<BookingMealRecord>> RecordsAsync(CancellationToken ct) =>
            await db.BookingMealRecords.Where(x => x.BookingId == bookingId).OrderBy(x => x.RecordedAt).ToListAsync(ct);
        public void Add(BookingMealPlan plan) => db.BookingMealPlans.Add(plan);
        public async Task<IReadOnlyList<BookingMealCorrection>> CorrectionsAsync(CancellationToken ct) =>
            await db.BookingMealCorrections.Where(x => x.BookingId == bookingId).OrderBy(x => x.Revision).ToListAsync(ct);
        public void Add(BookingMealCorrection correction, CareTimelineEvent timelineEvent)
        {
            db.BookingMealCorrections.Add(correction);
            db.TimelineEvents.Add(timelineEvent);
        }
        public void Add(BookingMealRecord record, CareTimelineEvent timelineEvent)
        {
            db.BookingMealRecords.Add(record);
            db.TimelineEvents.Add(timelineEvent);
        }
    }
}
