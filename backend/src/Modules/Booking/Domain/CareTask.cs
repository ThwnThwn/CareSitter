namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Nhiem vu chăm sóc trong 1 ca. Map sang bang booking.care_tasks.
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
    public Guid? CompletedBy { get; private set; }
    public string? SkipReason { get; private set; }
    public string Source { get; private set; } = "PACKAGE";
    public Guid? TemplateId { get; private set; }
    public Guid? CreatedBy { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static CareTask Create(Guid bookingId, string name, string? description = null,
        bool isRequired = false, bool requiresPhoto = false, int sortOrder = 0,
        string source = "PACKAGE", Guid? templateId = null, Guid? createdBy = null)
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
            Status = "PENDING",
            Source = source,
            TemplateId = templateId,
            CreatedBy = createdBy,
            CreatedAt = DateTimeOffset.UtcNow
        };
    }

    public void MarkCompleted(Guid caregiverUserId)
    {
        Status = "COMPLETED";
        CompletedAt = DateTimeOffset.UtcNow;
        CompletedBy = caregiverUserId;
    }

    public void Skip(string reason)
    {
        Status = "SKIPPED";
        SkipReason = reason.Trim();
    }

    public void SkipBySystem(string reason)
    {
        Status = "SKIPPED";
        SkipReason = reason;
    }
}
