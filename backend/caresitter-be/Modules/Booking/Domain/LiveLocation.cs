namespace CareSitter.Modules.Booking.Domain;

public sealed class LiveLocation
{
    public Guid BookingId { get; set; }
    public Guid CaregiverId { get; set; }
    public Guid TrackingSessionId { get; set; }
    public Guid SourceInstanceId { get; set; }
    public long LocationVersion { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public double? AccuracyMeters { get; set; }
    public double? SpeedMps { get; set; }
    public double? HeadingDegrees { get; set; }
    public DateTimeOffset? CapturedAt { get; set; }
    public DateTimeOffset? ReceivedAt { get; set; }
    public DateTimeOffset SessionLeaseUntil { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
}
