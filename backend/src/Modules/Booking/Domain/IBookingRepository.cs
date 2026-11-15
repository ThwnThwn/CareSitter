namespace CareSitter.Modules.Booking.Domain;

public interface IBookingRepository
{
    Task<Booking?> GetByIdAsync(Guid bookingId, CancellationToken ct);
    Task<Booking?> GetByIdReadOnlyAsync(Guid bookingId, CancellationToken ct);
    Task<Booking?> GetForCustomerAsync(Guid bookingId, Guid customerId, CancellationToken ct);
    Task<bool> HasBeneficiaryScheduleConflictAsync(Guid bookingId, Guid beneficiaryId,
        DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct);
    Task<bool> HasCaregiverScheduleConflictAsync(Guid bookingId, Guid caregiverId,
        DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct);
    Task<List<CareTask>> GetPendingCareTasksAsync(Guid bookingId, CancellationToken ct);
    Task<bool> HasPendingCareTasksAsync(Guid bookingId, CancellationToken ct);
    Task<bool> HasRequiredSkippedCareTasksAsync(Guid bookingId, CancellationToken ct);
    Task<List<CaregiverSlotHold>> GetActiveSlotHoldsAsync(Guid bookingId, CancellationToken ct);
    Task<CaregiverSlotHold?> GetActiveSlotHoldAsync(Guid bookingId, CancellationToken ct);
    Task<BookingAssignment?> GetActiveAssignmentReadOnlyAsync(Guid bookingId, Guid caregiverId,
        DateTimeOffset now, CancellationToken ct);
    Task<bool> HasAnyAssignmentAsync(Guid bookingId, CancellationToken ct);
    Task<BookingAssignment?> GetActiveAssignmentAsync(Guid bookingId, Guid caregiverId,
        CancellationToken ct);
    Task<List<BookingAssignment>> GetOtherOfferedAssignmentsAsync(Guid bookingId, Guid caregiverId,
        CancellationToken ct);
    Task<BookingAssignment?> GetAssignmentAsync(Guid bookingId, Guid caregiverId,
        CancellationToken ct);
    Task<bool> HasActiveOfferAsync(Guid bookingId, DateTimeOffset now, CancellationToken ct);
    void Add(Booking booking);
    void AddSlotHold(CaregiverSlotHold slotHold);
    void AddAssignment(BookingAssignment assignment);
    void AddTimelineEvent(CareTimelineEvent timelineEvent);
    Task SaveChangesAsync(CancellationToken ct);
    Task<bool> TrySaveSlotHoldChangesAsync(CancellationToken ct);
}
