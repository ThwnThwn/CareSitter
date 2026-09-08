namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Nhiem vu cham soc trong 1 ca. Map sang bang booking.care_tasks.
/// </summary>
public sealed class CareTask
{
    private CareTask() { } // EF

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? Description { get; private set; }
    public bool IsRequired { get; private set; }
    public bool RequiresPhoto { get; private set; }
    public int SortOrder { get; private set; }
    public string Status { get; private set; } = "PENDING";
    public DateTimeOffset? CompletedAt { get; private set; }

    public static CareTask Create(Guid bookingId, string name, string? description = null,
        bool isRequired = false, bool requiresPhoto = false, int sortOrder = 0)
    {
        return new CareTask
        {
            Id = Guid.NewGuid(),
            BookingId = bookingId,
            Name = name,
            Description = description,
            IsRequired = isRequired,
            RequiresPhoto = requiresPhoto,
            SortOrder = sortOrder,
            Status = "PENDING"
        };
    }

    public void MarkDone()
    {
        Status = "DONE";
        CompletedAt = DateTimeOffset.UtcNow;
    }

    public void Skip()
    {
        Status = "SKIPPED";
    }
}
