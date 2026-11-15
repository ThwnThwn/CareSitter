using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingMealCorrectionConfiguration : IEntityTypeConfiguration<BookingMealCorrection>
{
    public void Configure(EntityTypeBuilder<BookingMealCorrection> b)
    {
        b.ToTable("booking_meal_corrections"); b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.RecordId).HasColumnName("record_id");
        b.Property(x => x.Revision).HasColumnName("revision");
        b.Property(x => x.Outcome).HasColumnName("outcome").HasMaxLength(20);
        b.Property(x => x.Note).HasColumnName("note").HasMaxLength(1000);
        b.Property(x => x.Reason).HasColumnName("reason").HasMaxLength(500);
        b.Property(x => x.CorrectedBy).HasColumnName("corrected_by");
        b.Property(x => x.CorrectedAt).HasColumnName("corrected_at");
        b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key");
        b.Property(x => x.TimelineEventId).HasColumnName("timeline_event_id");
        b.HasIndex(x => new { x.BookingId, x.IdempotencyKey }).IsUnique();
        b.HasIndex(x => new { x.RecordId, x.Revision }).IsUnique();
        b.HasOne<Domain.Booking>().WithMany().HasForeignKey(x => x.BookingId);
        b.HasOne<BookingMealRecord>().WithMany().HasForeignKey(x => x.RecordId);
        b.HasOne<CareTimelineEvent>().WithMany().HasForeignKey(x => x.TimelineEventId);
    }
}
