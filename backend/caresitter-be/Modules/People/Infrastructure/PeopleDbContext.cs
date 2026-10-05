using CareSitter.Infrastructure.Persistence;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

/// <summary>DbContext module People — schema "people" (beneficiaries, caregiver_profiles).</summary>
public sealed class PeopleDbContext : ModuleDbContext
{
    public const string SchemaName = "people";

    public PeopleDbContext(DbContextOptions<PeopleDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<Beneficiary> Beneficiaries => Set<Beneficiary>();
    public DbSet<FamilyContact> FamilyContacts => Set<FamilyContact>();
    public DbSet<CaregiverProfile> CaregiverProfiles => Set<CaregiverProfile>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Beneficiary>(b =>
        {
            b.ToTable("beneficiaries");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.FullName).HasColumnName("full_name").HasMaxLength(255);
            b.Property(x => x.DateOfBirth).HasColumnName("date_of_birth").HasColumnType("date");
            b.Property(x => x.Gender).HasColumnName("gender").HasMaxLength(20);
            b.Property(x => x.RelationshipToCustomer).HasColumnName("relationship_to_customer").HasMaxLength(100);
            b.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(20);
            b.Property(x => x.DefaultAddressId).HasColumnName("default_address_id");
            b.Property(x => x.MobilityNote).HasColumnName("mobility_note");
            b.Property(x => x.GeneralNote).HasColumnName("general_note");
            b.Property(x => x.HealthHistory).HasColumnName("health_history").HasColumnType("jsonb");
            b.Property(x => x.Allergies).HasColumnName("allergies").HasColumnType("jsonb");
            b.Property(x => x.ChronicConditions).HasColumnName("chronic_conditions").HasColumnType("jsonb");
            b.Property(x => x.CareInstructions).HasColumnName("care_instructions");
            b.Property(x => x.CareLevel).HasColumnName("care_level").HasMaxLength(20);
            b.Property(x => x.AvatarUrl).HasColumnName("avatar_url");
            b.Property(x => x.EmergencyContacts).HasColumnName("emergency_contacts").HasColumnType("jsonb");
            b.Property(x => x.Medications).HasColumnName("medications").HasColumnType("jsonb");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at"); // trg_beneficiaries_updated
            b.Property(x => x.DeletedAt).HasColumnName("deleted_at");
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<FamilyContact>(b =>
        {
            b.ToTable("family_contacts");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.FullName).HasColumnName("full_name").HasMaxLength(255);
            b.Property(x => x.PhoneNumber).HasColumnName("phone_number").HasMaxLength(20);
            b.Property(x => x.Note).HasColumnName("note").HasMaxLength(500);
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Property(x => x.DeletedAt).HasColumnName("deleted_at");
            b.HasIndex(x => new { x.CustomerId, x.PhoneNumber }).HasFilter("deleted_at IS NULL").IsUnique();
        });

        modelBuilder.Entity<CaregiverProfile>(b =>
        {
            b.ToTable("caregiver_profiles");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.HasIndex(x => x.UserId).IsUnique();
            b.Property(x => x.FullName).HasColumnName("full_name").HasMaxLength(255);
            b.Property(x => x.DateOfBirth).HasColumnName("date_of_birth").HasColumnType("date");
            b.Property(x => x.Gender).HasColumnName("gender").HasMaxLength(20);
            b.Property(x => x.CccdNumberEncrypted).HasColumnName("cccd_number_encrypted");
            b.Property(x => x.CccdHash).HasColumnName("cccd_hash");
            b.Property(x => x.CccdFrontUrl).HasColumnName("cccd_front_url");
            b.Property(x => x.CccdBackUrl).HasColumnName("cccd_back_url");
            b.Property(x => x.CertificateUrls).HasColumnName("certificate_urls").HasColumnType("jsonb");
            b.Property(x => x.CccdFrontMediaId).HasColumnName("cccd_front_media_id");
            b.Property(x => x.CccdBackMediaId).HasColumnName("cccd_back_media_id");
            b.Property(x => x.CertificateMediaIds).HasColumnName("certificate_media_ids").HasColumnType("jsonb");
            b.Property(x => x.Bio).HasColumnName("bio");
            b.Property(x => x.YearsOfExperience).HasColumnName("years_of_experience");
            b.Property(x => x.RatingAvg).HasColumnName("rating_avg").HasColumnType("numeric(3,2)");
            b.Property(x => x.RatingCount).HasColumnName("rating_count");
            b.Property(x => x.KycStatus).HasColumnName("kyc_status").HasMaxLength(50);
            b.Property(x => x.AvailabilityStatus).HasColumnName("availability_status").HasMaxLength(20);
            b.Property(x => x.Skills).HasColumnName("skills").HasColumnType("jsonb");
            b.Property(x => x.ServiceCity).HasColumnName("service_city").HasMaxLength(100);
            b.Property(x => x.ServiceDistrict).HasColumnName("service_district").HasMaxLength(100);
            b.Property(x => x.ServiceCenterLocation).HasColumnName("service_center_location")
                .HasColumnType("geography(Point,4326)");
            b.Property(x => x.ServiceRadiusMeters).HasColumnName("service_radius_meters");
            b.Property(x => x.WalletAccountId).HasColumnName("wallet_account_id");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at"); // trg_caregiver_updated
            b.Property(x => x.DeletedAt).HasColumnName("deleted_at");
            b.Ignore(x => x.DomainEvents);
        });

    }
}
