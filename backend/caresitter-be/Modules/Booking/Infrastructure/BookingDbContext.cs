using CareSitter.Infrastructure.Persistence;
using CareSitter.Contracts.Services;
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
    public DbSet<CaregiverSlotHold> CaregiverSlotHolds => Set<CaregiverSlotHold>();
    public DbSet<CareTask> CareTasks => Set<CareTask>();
    public DbSet<PackageTaskTemplate> PackageTaskTemplates => Set<PackageTaskTemplate>();
    public DbSet<CareTimelineEvent> TimelineEvents => Set<CareTimelineEvent>();
    public DbSet<GpsTrack> GpsTracks => Set<GpsTrack>();
    public DbSet<BookingSyncEvent> BookingSyncEvents => Set<BookingSyncEvent>();

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
            b.Property(x => x.PaymentDeadline).HasColumnName("payment_deadline");
            b.Property(x => x.ActualStart).HasColumnName("actual_start");
            b.Property(x => x.ActualEnd).HasColumnName("actual_end");
            b.Property(x => x.CheckoutPendingReviewAt).HasColumnName("checkout_pending_review_at");
            b.Property(x => x.CheckoutSource)
                .HasColumnName("checkout_source")
                .HasConversion<string>()
                .HasMaxLength(30);
            b.Property(x => x.NeedsReview).HasColumnName("needs_review");
            b.Property(x => x.AllowAdHocTasks).HasColumnName("allow_ad_hoc_tasks");
            b.Property(x => x.RequiredSkills).HasColumnName("required_skills").HasColumnType("jsonb");
            b.Property(x => x.Status)
                .HasColumnName("status")
                .HasConversion(v => BookingStatusCodec.ToDatabase(v), v => BookingStatusCodec.FromDatabase(v))
                .HasMaxLength(50);
            b.Property(x => x.EscrowAmount).HasColumnName("escrow_amount");
            b.Property(x => x.PlatformFeeAmount).HasColumnName("platform_fee_amount");
            b.Property(x => x.CaregiverEarningAmount).HasColumnName("caregiver_earning_amount");
            b.Property(x => x.PriceSnapshot).HasColumnName("price_snapshot").HasColumnType("jsonb");
            b.Property(x => x.DisputeWindowHours).HasColumnName("dispute_window_hours");
            b.Property(x => x.SettlementReleasedAt).HasColumnName("settlement_released_at");
            b.Property(x => x.GeofenceRadiusMeters).HasColumnName("geofence_radius_meters");
            b.Property(x => x.CancelledAt).HasColumnName("cancelled_at");
            b.Property(x => x.CancelledByUserId).HasColumnName("cancelled_by_user_id");
            b.Property(x => x.CancelledByRole).HasColumnName("cancelled_by_role");
            b.Property(x => x.CancelReason).HasColumnName("cancel_reason");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Property(x => x.SyncVersion)
                .HasColumnName("sync_version")
                .IsConcurrencyToken();
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<BookingSyncEvent>(b =>
        {
            b.ToTable("booking_sync_events");
            b.HasKey(x => x.Cursor);
            b.Property(x => x.Cursor)
                .HasColumnName("cursor")
                .ValueGeneratedOnAdd();
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.BookingVersion).HasColumnName("booking_version");
            b.Property(x => x.EventType).HasColumnName("event_type").HasMaxLength(50);
            b.Property(x => x.OccurredAt).HasColumnName("occurred_at");
            // Khai báo quan hệ để EF sắp xếp INSERT booking trước sync event
            // khi tạo booking và event trong cùng một SaveChangesAsync.
            b.HasOne<Domain.Booking>()
                .WithMany()
                .HasForeignKey(x => x.BookingId)
                .HasPrincipalKey(x => x.Id)
                .OnDelete(DeleteBehavior.Cascade);
            b.HasIndex(x => new { x.CustomerId, x.Cursor }).HasDatabaseName("ix_bse_customer_cursor");
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
            b.Property(x => x.DeclineReason).HasColumnName("decline_reason").HasMaxLength(200);
        });

        modelBuilder.Entity<CaregiverSlotHold>(b =>
        {
            b.ToTable("caregiver_slot_holds");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.ScheduledStart).HasColumnName("scheduled_start");
            b.Property(x => x.ScheduledEnd).HasColumnName("scheduled_end");
            b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.ReleasedAt).HasColumnName("released_at");
            b.Ignore(x => x.UpdatedAt); // bảng hold không cần updated_at
            b.HasIndex(x => new { x.BookingId, x.Status })
                .HasDatabaseName("ix_slot_hold_booking_status");
            b.HasIndex(x => new { x.CaregiverId, x.Status, x.ExpiresAt })
                .HasDatabaseName("ix_slot_hold_caregiver_status_expiry");
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
            b.Property(x => x.CompletedBy).HasColumnName("completed_by");
            b.Property(x => x.SkipReason).HasColumnName("skip_reason").HasMaxLength(500);
            b.Property(x => x.Source).HasColumnName("source").HasMaxLength(30);
            b.Property(x => x.TemplateId).HasColumnName("template_id");
            b.Property(x => x.CreatedBy).HasColumnName("created_by");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
        });

        modelBuilder.Entity<PackageTaskTemplate>(b =>
        {
            b.ToTable("package_task_templates");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.ServiceTypeId).HasColumnName("service_type_id");
            b.Property(x => x.Name).HasColumnName("name").HasMaxLength(255);
            b.Property(x => x.Description).HasColumnName("description");
            b.Property(x => x.IsRequired).HasColumnName("is_required");
            b.Property(x => x.RequiresPhoto).HasColumnName("requires_photo");
            b.Property(x => x.SortOrder).HasColumnName("sort_order");
            b.Property(x => x.IsActive).HasColumnName("is_active");
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
