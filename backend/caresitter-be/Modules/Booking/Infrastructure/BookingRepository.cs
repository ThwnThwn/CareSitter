using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingRepository(BookingDbContext db) : IBookingRepository
{
    public Task<Domain.Booking?> GetByIdAsync(Guid bookingId, CancellationToken ct) =>
        db.Bookings.SingleOrDefaultAsync(x => x.Id == bookingId, ct);

    public Task<Domain.Booking?> GetByIdReadOnlyAsync(Guid bookingId, CancellationToken ct) =>
        db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == bookingId, ct);

    public Task<Domain.Booking?> GetForCustomerAsync(Guid bookingId, Guid customerId, CancellationToken ct) =>
        db.Bookings.SingleOrDefaultAsync(x => x.Id == bookingId && x.CustomerId == customerId, ct);

    public Task<bool> HasBeneficiaryScheduleConflictAsync(Guid bookingId, Guid beneficiaryId,
        DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) =>
        db.Bookings.AsNoTracking().AnyAsync(x =>
            x.Id != bookingId &&
            x.BeneficiaryId == beneficiaryId &&
            x.Status != BookingStatus.Completed &&
            x.Status != BookingStatus.Cancelled &&
            x.Status != BookingStatus.Refunded &&
            x.Status != BookingStatus.MatchingFailed &&
            x.ScheduledStart < scheduledEnd &&
            x.ScheduledEnd > scheduledStart, ct);

    public Task<bool> HasCaregiverScheduleConflictAsync(Guid bookingId, Guid caregiverId,
        DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) =>
        db.Bookings.AsNoTracking().AnyAsync(x =>
            x.Id != bookingId &&
            x.CaregiverId == caregiverId &&
            x.Status != BookingStatus.Completed &&
            x.Status != BookingStatus.Cancelled &&
            x.Status != BookingStatus.Refunded &&
            x.Status != BookingStatus.MatchingFailed &&
            x.ScheduledStart < scheduledEnd &&
            x.ScheduledEnd > scheduledStart, ct);

    public Task<List<CareTask>> GetPendingCareTasksAsync(Guid bookingId, CancellationToken ct) =>
        db.CareTasks.Where(x => x.BookingId == bookingId && x.Status == "PENDING").ToListAsync(ct);

    public Task<bool> HasPendingCareTasksAsync(Guid bookingId, CancellationToken ct) =>
        db.CareTasks.AnyAsync(x => x.BookingId == bookingId && x.Status == "PENDING", ct);

    public Task<bool> HasRequiredSkippedCareTasksAsync(Guid bookingId, CancellationToken ct) =>
        db.CareTasks.AnyAsync(x => x.BookingId == bookingId && x.IsRequired && x.Status == "SKIPPED", ct);

    public Task<List<CaregiverSlotHold>> GetActiveSlotHoldsAsync(Guid bookingId, CancellationToken ct) =>
        db.CaregiverSlotHolds
            .Where(x => x.BookingId == bookingId && (x.Status == "HELD" || x.Status == "COMMITTED"))
            .ToListAsync(ct);

    public Task<CaregiverSlotHold?> GetActiveSlotHoldAsync(Guid bookingId, CancellationToken ct) =>
        db.CaregiverSlotHolds.SingleOrDefaultAsync(x => x.BookingId == bookingId
            && (x.Status == "HELD" || x.Status == "COMMITTED"), ct);

    public Task<BookingAssignment?> GetActiveAssignmentReadOnlyAsync(Guid bookingId, Guid caregiverId,
        DateTimeOffset now, CancellationToken ct) =>
        db.BookingAssignments.AsNoTracking().SingleOrDefaultAsync(x =>
            x.BookingId == bookingId && x.CaregiverId == caregiverId
            && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
            && x.ExpiresAt != null && x.ExpiresAt > now, ct);

    public Task<bool> HasAnyAssignmentAsync(Guid bookingId, CancellationToken ct) =>
        db.BookingAssignments.AsNoTracking().AnyAsync(x => x.BookingId == bookingId, ct);

    public Task<BookingAssignment?> GetActiveAssignmentAsync(Guid bookingId, Guid caregiverId,
        CancellationToken ct) =>
        db.BookingAssignments.SingleOrDefaultAsync(x => x.BookingId == bookingId
            && x.CaregiverId == caregiverId
            && (x.Status == "OFFERED" || x.Status == "SUGGESTED"), ct);

    public Task<List<BookingAssignment>> GetOtherOfferedAssignmentsAsync(Guid bookingId, Guid caregiverId,
        CancellationToken ct) =>
        db.BookingAssignments
            .Where(x => x.BookingId == bookingId && x.CaregiverId != caregiverId && x.Status == "OFFERED")
            .ToListAsync(ct);

    public Task<BookingAssignment?> GetAssignmentAsync(Guid bookingId, Guid caregiverId,
        CancellationToken ct) =>
        db.BookingAssignments.SingleOrDefaultAsync(
            x => x.BookingId == bookingId && x.CaregiverId == caregiverId, ct);

    public Task<bool> HasActiveOfferAsync(Guid bookingId, DateTimeOffset now, CancellationToken ct) =>
        db.BookingAssignments.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
            && x.ExpiresAt != null && x.ExpiresAt > now, ct);

    public void Add(Domain.Booking booking) => db.Bookings.Add(booking);
    public void AddSlotHold(CaregiverSlotHold slotHold) => db.CaregiverSlotHolds.Add(slotHold);
    public void AddAssignment(BookingAssignment assignment) => db.BookingAssignments.Add(assignment);
    public void AddTimelineEvent(CareTimelineEvent timelineEvent) => db.TimelineEvents.Add(timelineEvent);
    public Task SaveChangesAsync(CancellationToken ct) => db.SaveChangesAsync(ct);

    public async Task<bool> TrySaveSlotHoldChangesAsync(CancellationToken ct)
    {
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException)
        {
            return false;
        }
    }
}
