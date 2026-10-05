using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class LiveLocationConfiguration : IEntityTypeConfiguration<LiveLocation>
{
    public void Configure(EntityTypeBuilder<LiveLocation> b)
    {
        b.ToTable("live_locations", "booking");
        b.HasKey(x => x.BookingId);
        b.HasOne<Domain.Booking>().WithOne().HasForeignKey<LiveLocation>(x => x.BookingId).OnDelete(DeleteBehavior.Cascade);
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
        b.Property(x => x.TrackingSessionId).HasColumnName("tracking_session_id");
        b.Property(x => x.SourceInstanceId).HasColumnName("source_instance_id");
        b.Property(x => x.LocationVersion).HasColumnName("location_version");
        b.Property(x => x.Latitude).HasColumnName("latitude");
        b.Property(x => x.Longitude).HasColumnName("longitude");
        b.Property(x => x.AccuracyMeters).HasColumnName("accuracy_meters");
        b.Property(x => x.SpeedMps).HasColumnName("speed_mps");
        b.Property(x => x.HeadingDegrees).HasColumnName("heading_degrees");
        b.Property(x => x.CapturedAt).HasColumnName("captured_at");
        b.Property(x => x.ReceivedAt).HasColumnName("received_at");
        b.Property(x => x.SessionLeaseUntil).HasColumnName("session_lease_until");
        b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
    }
}
