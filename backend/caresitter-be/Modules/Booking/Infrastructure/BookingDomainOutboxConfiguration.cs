using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingDomainOutboxConfiguration
    : IEntityTypeConfiguration<BookingDomainOutboxEvent>
{
    public void Configure(EntityTypeBuilder<BookingDomainOutboxEvent> b)
    {
        b.ToTable("booking_domain_outbox", BookingDbContext.SchemaName);
        b.HasKey(x => x.EventId);
        b.Property(x => x.EventId).HasColumnName("event_id");
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.BookingVersion).HasColumnName("booking_version");
        b.Property(x => x.EventType).HasColumnName("event_type").HasMaxLength(100);
        b.Property(x => x.Payload).HasColumnName("payload").HasColumnType("jsonb");
        b.Property(x => x.OccurredAt).HasColumnName("occurred_at");
        b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
        b.Property(x => x.Attempts).HasColumnName("attempts");
        b.Property(x => x.AvailableAt).HasColumnName("available_at");
        b.Property(x => x.LeaseUntil).HasColumnName("lease_until");
        b.Property(x => x.ClaimToken).HasColumnName("claim_token");
        b.Property(x => x.LastError).HasColumnName("last_error").HasMaxLength(500);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        b.Property(x => x.ProcessedAt).HasColumnName("processed_at");
        b.HasOne<Domain.Booking>().WithMany().HasForeignKey(x => x.BookingId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.Status, x.AvailableAt, x.OccurredAt })
            .HasDatabaseName("ix_booking_domain_outbox_dispatch");
    }
}
