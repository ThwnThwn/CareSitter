using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class ConsultationRequestConfiguration : IEntityTypeConfiguration<ConsultationRequest>
{
    public void Configure(EntityTypeBuilder<ConsultationRequest> b)
    {
        b.ToTable("consultation_requests", SupportDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.ContactName).HasColumnName("contact_name").HasMaxLength(120);
        b.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(10);
        b.Property(x => x.ServiceCategory).HasColumnName("service_category").HasMaxLength(40);
        b.Property(x => x.PreferredDate).HasColumnName("preferred_date");
        b.Property(x => x.Hours).HasColumnName("hours").HasColumnType("smallint");
        b.Property(x => x.CaregiverPreference).HasColumnName("caregiver_preference").HasMaxLength(120);
        b.Property(x => x.Note).HasColumnName("note").HasMaxLength(1000);
        b.Property(x => x.ConsentAt).HasColumnName("consent_at");
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.PayloadHash).HasColumnName("payload_hash").HasMaxLength(64);
    }
}
