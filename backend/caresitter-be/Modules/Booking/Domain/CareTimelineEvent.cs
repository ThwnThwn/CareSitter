namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Su kien dong thoi gian trong ca chăm sóc. Map sang bang booking.care_timeline_events.
/// </summary>
public sealed class CareTimelineEvent
{
    private CareTimelineEvent() { } // EF

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid? CaregiverId { get; private set; }
    public Guid? TaskId { get; private set; }
    public string EventType { get; private set; } = string.Empty;
    public string? Title { get; private set; }
    public string? Note { get; private set; }
    public Guid? MediaId { get; private set; }
    public double? Latitude { get; private set; }
    public double? Longitude { get; private set; }
    public double? DistanceToAddressMeters { get; private set; }
    public DateTimeOffset RecordedAt { get; private set; }
    public DateTimeOffset? SyncedAt { get; private set; }
    public string Source { get; private set; } = "ONLINE";
    public string? Metadata { get; private set; }

    public static CareTimelineEvent Create(Guid bookingId, Guid? caregiverId, string eventType,
        string? title = null, string? note = null, Guid? taskId = null,
        double? latitude = null, double? longitude = null,
        double? distanceToAddressMeters = null, string source = "ONLINE",
        string? metadata = null)
    {
        return new CareTimelineEvent
        {
            Id = Guid.NewGuid(),
            BookingId = bookingId,
            CaregiverId = caregiverId,
            TaskId = taskId,
            EventType = eventType,
            Title = title,
            Note = note,
            Latitude = latitude,
            Longitude = longitude,
            DistanceToAddressMeters = distanceToAddressMeters,
            RecordedAt = DateTimeOffset.UtcNow,
            Source = source,
            Metadata = metadata
        };
    }

    public CareTimelineEvent WithMedia(Guid mediaId)
    {
        MediaId = mediaId;
        return this;
    }
}
