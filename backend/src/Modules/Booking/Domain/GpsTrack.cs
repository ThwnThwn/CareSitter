namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Diem GPS caregiver trong ca chăm sóc. Map sang bang booking.gps_tracks.
/// </summary>
public sealed class GpsTrack
{
    private GpsTrack() { } // EF

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid CaregiverId { get; private set; }
    public double Latitude { get; private set; }
    public double Longitude { get; private set; }
    public double? AccuracyMeters { get; private set; }
    public double? Speed { get; private set; }
    public double? Heading { get; private set; }
    public DateTimeOffset RecordedAt { get; private set; }
    public DateTimeOffset ReceivedAt { get; private set; }

    public static GpsTrack Create(Guid bookingId, Guid caregiverId,
        double latitude, double longitude, double? accuracyMeters = null,
        double? speed = null, double? heading = null)
    {
        return new GpsTrack
        {
            Id = Guid.NewGuid(),
            BookingId = bookingId,
            CaregiverId = caregiverId,
            Latitude = latitude,
            Longitude = longitude,
            AccuracyMeters = accuracyMeters,
            Speed = speed,
            Heading = heading,
            RecordedAt = DateTimeOffset.UtcNow,
            ReceivedAt = DateTimeOffset.UtcNow
        };
    }
}
