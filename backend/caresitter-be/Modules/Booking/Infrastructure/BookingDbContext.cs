using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>DbContext module Booking — map vao schema "booking".</summary>
public sealed class BookingDbContext : ModuleDbContext
{
    public const string SchemaName = "booking";

    public BookingDbContext(DbContextOptions<BookingDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<Domain.Booking> Bookings => Set<Domain.Booking>();
    public DbSet<BookingAssignment> BookingAssignments => Set<BookingAssignment>();
    public DbSet<CareTask> CareTasks => Set<CareTask>();
    public DbSet<CareTimelineEvent> TimelineEvents => Set<CareTimelineEvent>();
    public DbSet<GpsTrack> GpsTracks => Set<GpsTrack>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Domain.Booking>(b =>
        {
            b.ToTable("bookings");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.BeneficiaryId).HasColumnName("beneficiary_id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.AddressId).HasColumnName("address_id");
            b.Property(x => x.ServiceTypeId).HasColumnName("service_type_id");
            b.Property(x => x.ScheduledStart).HasColumnName("scheduled_start");
            b.Property(x => x.ScheduledEnd).HasColumnName("scheduled_end");
            b.Property(x => x.ActualStart).HasColumnName("actual_start");
            b.Property(x => x.ActualEnd).HasColumnName("actual_end");
            b.Property(x => x.RequiredSkills).HasColumnName("required_skills").HasColumnType("jsonb");
            b.Property(x => x.Status)
                .HasColumnName("status")
                .HasConversion(v => BookingStatusCodec.ToDatabase(v), v => BookingStatusCodec.FromDatabase(v))
                .HasMaxLength(50);
            b.Property(x => x.EscrowAmount).HasColumnName("escrow_amount");
            b.Property(x => x.PlatformFeeAmount).HasColumnName("platform_fee_amount");
            b.Property(x => x.CaregiverEarningAmount).HasColumnName("caregiver_earning_amount");
            b.Property(x => x.PriceSnapshot).HasColumnName("price_snapshot").HasColumnType("jsonb");
            b.Property(x => x.GeofenceRadiusMeters).HasColumnName("geofence_radius_meters");
            b.Property(x => x.CancelledAt).HasColumnName("cancelled_at");
            b.Property(x => x.CancelledByUserId).HasColumnName("cancelled_by_user_id");
            b.Property(x => x.CancelledByRole).HasColumnName("cancelled_by_role");
            b.Property(x => x.CancelReason).HasColumnName("cancel_reason");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<BookingAssignment>(b =>
        {
            b.ToTable("booking_assignments");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.AssignmentType).HasColumnName("assignment_type").HasMaxLength(20);
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.Rank).HasColumnName("rank");
            b.Property(x => x.DistanceMeters).HasColumnName("distance_meters");
            b.Property(x => x.Score).HasColumnName("score");
            b.Property(x => x.ScoreBreakdown).HasColumnName("score_breakdown").HasColumnType("jsonb");
            b.Property(x => x.OfferedAt).HasColumnName("offered_at");
            b.Property(x => x.RespondedAt).HasColumnName("responded_at");
            b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
        });

        modelBuilder.Entity<CareTask>(b =>
        {
            b.ToTable("care_tasks");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.Name).HasColumnName("name").HasMaxLength(255);
            b.Property(x => x.Description).HasColumnName("description");
            b.Property(x => x.IsRequired).HasColumnName("is_required");
            b.Property(x => x.RequiresPhoto).HasColumnName("requires_photo");
            b.Property(x => x.SortOrder).HasColumnName("sort_order");
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.CompletedAt).HasColumnName("completed_at");
        });

        modelBuilder.Entity<CareTimelineEvent>(b =>
        {
            b.ToTable("care_timeline_events");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.TaskId).HasColumnName("task_id");
            b.Property(x => x.EventType).HasColumnName("event_type").HasMaxLength(30);
            b.Property(x => x.Title).HasColumnName("title").HasMaxLength(255);
            b.Property(x => x.Note).HasColumnName("note");
            b.Property(x => x.MediaId).HasColumnName("media_id");
            // coordinates stored via lat/lng columns (ignore PostGIS geography for now)
            b.Property(x => x.Latitude).HasColumnName("latitude");
            b.Property(x => x.Longitude).HasColumnName("longitude");
            b.Property(x => x.DistanceToAddressMeters).HasColumnName("distance_to_address_meters");
            b.Property(x => x.RecordedAt).HasColumnName("recorded_at");
            b.Property(x => x.SyncedAt).HasColumnName("synced_at");
            b.Property(x => x.Source).HasColumnName("source").HasMaxLength(20);
            b.Property(x => x.Metadata).HasColumnName("metadata").HasColumnType("jsonb");
        });

        modelBuilder.Entity<GpsTrack>(b =>
        {
            b.ToTable("gps_tracks");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.Latitude).HasColumnName("latitude");
            b.Property(x => x.Longitude).HasColumnName("longitude");
            b.Property(x => x.AccuracyMeters).HasColumnName("accuracy_meters");
            b.Property(x => x.Speed).HasColumnName("speed");
            b.Property(x => x.Heading).HasColumnName("heading");
            b.Property(x => x.RecordedAt).HasColumnName("recorded_at");
            b.Property(x => x.ReceivedAt).HasColumnName("received_at");
        });
    }
}
