namespace CareSitter.Modules.Booking.Application;

public sealed class LiveTrackingOptions
{
    public const string SectionName = "LiveTracking";
    public bool Enabled { get; set; }
    public int SendIntervalSeconds { get; set; } = 10;
    public int LeaseSeconds { get; set; } = 120;
    public int RetentionHours { get; set; } = 24;
    public int MaxSampleAgeSeconds { get; set; } = 60;
    public int MaxFutureSkewSeconds { get; set; } = 30;
}
