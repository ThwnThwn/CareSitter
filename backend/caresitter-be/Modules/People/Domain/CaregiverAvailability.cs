using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Domain;

/// <summary>
/// Khoang thoi gian ranh/ban cua caregiver. Map sang bang people.caregiver_availability.
/// Bang khong co created_at/updated_at (khong co trg_*_updated) -> Ignore ca hai.
/// Cot time_range la GENERATED ALWAYS (tstzrange) phuc vu EXCLUDE constraint chong double-book,
/// nen KHONG map (readonly generated) — xem note trong DbContext.
/// </summary>
public sealed class CaregiverAvailability : Entity
{
    private CaregiverAvailability() { } // EF

    private CaregiverAvailability(
        Guid id,
        Guid caregiverId,
        DateTimeOffset startAt,
        DateTimeOffset endAt,
        string status,
        string source)
    {
        Id = id;
        CaregiverId = caregiverId;
        StartAt = startAt;
        EndAt = endAt;
        Status = status;
        Source = source;
    }

    public Guid CaregiverId { get; private set; }
    public DateTimeOffset StartAt { get; private set; }
    public DateTimeOffset EndAt { get; private set; }

    /// <summary>Allowed values: AVAILABLE, BLOCKED, BOOKED.</summary>
    public string Status { get; private set; } = "AVAILABLE";

    /// <summary>Allowed values: CAREGIVER, BOOKING, ADMIN.</summary>
    public string Source { get; private set; } = "CAREGIVER";

    public static Result<CaregiverAvailability> Create(
        Guid caregiverId,
        DateTimeOffset startAt,
        DateTimeOffset endAt,
        string status = "AVAILABLE",
        string source = "CAREGIVER")
    {
        if (caregiverId == Guid.Empty)
            return Error.Validation("caregiver_availability.caregiver", "caregiver_id la bat buoc.");
        if (endAt <= startAt)
            return Error.Validation("caregiver_availability.range", "end_at phai sau start_at.");

        return new CaregiverAvailability(Guid.NewGuid(), caregiverId, startAt, endAt, status, source);
    }
}
