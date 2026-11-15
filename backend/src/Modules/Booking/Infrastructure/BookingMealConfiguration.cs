using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingMealPlanConfiguration : IEntityTypeConfiguration<BookingMealPlan>
{
    public void Configure(EntityTypeBuilder<BookingMealPlan> b)
    {
        b.ToTable("booking_meal_plans");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.PlanId).HasColumnName("plan_id");
        b.Property(x => x.PlannedDate).HasColumnName("planned_date");
        b.Property(x => x.MealsJson).HasColumnName("meals_json").HasColumnType("jsonb");
        b.Property(x => x.HealthRevision).HasColumnName("health_revision");
        b.Property(x => x.HealthFingerprint).HasColumnName("health_fingerprint").HasMaxLength(64);
        b.Property(x => x.SharedBy).HasColumnName("shared_by");
        b.Property(x => x.SharedAt).HasColumnName("shared_at");
        b.Property(x => x.RevokedAt).HasColumnName("revoked_at");
        b.HasIndex(x => new { x.BookingId, x.PlannedDate }).IsUnique();
        b.HasOne<Domain.Booking>().WithMany().HasForeignKey(x => x.BookingId);
    }
}

internal sealed class BookingMealRecordConfiguration : IEntityTypeConfiguration<BookingMealRecord>
{
    public void Configure(EntityTypeBuilder<BookingMealRecord> b)
    {
        b.ToTable("booking_meal_records");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.PlanId).HasColumnName("plan_id");
        b.Property(x => x.PlannedDate).HasColumnName("planned_date");
        b.Property(x => x.RecipeVersionId).HasColumnName("recipe_version_id");
        b.Property(x => x.MealType).HasColumnName("meal_type").HasMaxLength(20);
        b.Property(x => x.Outcome).HasColumnName("outcome").HasMaxLength(20);
        b.Property(x => x.Note).HasColumnName("note").HasMaxLength(1000);
        b.Property(x => x.RecordedBy).HasColumnName("recorded_by");
        b.Property(x => x.RecordedAt).HasColumnName("recorded_at");
        b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key");
        b.Property(x => x.TimelineEventId).HasColumnName("timeline_event_id");
        b.HasIndex(x => new { x.BookingId, x.IdempotencyKey }).IsUnique();
        b.HasIndex(x => new { x.BookingId, x.PlannedDate, x.MealType }).IsUnique();
        b.HasOne<Domain.Booking>().WithMany().HasForeignKey(x => x.BookingId);
        b.HasOne<CareTimelineEvent>().WithMany().HasForeignKey(x => x.TimelineEventId);
    }
}
