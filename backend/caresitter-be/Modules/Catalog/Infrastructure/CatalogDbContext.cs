using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Catalog.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

/// <summary>DbContext module Catalog — schema "catalog" (service_types, pricing_rules, addresses, media_assets).</summary>
public sealed class CatalogDbContext : ModuleDbContext
{
    public const string SchemaName = "catalog";

    public CatalogDbContext(DbContextOptions<CatalogDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<MediaAsset> MediaAssets => Set<MediaAsset>();
    public DbSet<Address> Addresses => Set<Address>();
    public DbSet<ServiceType> ServiceTypes => Set<ServiceType>();
    public DbSet<PricingRule> PricingRules => Set<PricingRule>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<MediaAsset>(b =>
        {
            b.ToTable("media_assets");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.OwnerUserId).HasColumnName("owner_user_id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.StorageProvider).HasColumnName("storage_provider").HasMaxLength(50);
            b.Property(x => x.Bucket).HasColumnName("bucket").HasMaxLength(255);
            b.Property(x => x.ObjectKey).HasColumnName("object_key");
            b.Property(x => x.Url).HasColumnName("url");
            b.Property(x => x.MimeType).HasColumnName("mime_type").HasMaxLength(100);
            b.Property(x => x.SizeBytes).HasColumnName("size_bytes");
            b.Property(x => x.Checksum).HasColumnName("checksum");
            b.Property(x => x.MediaType).HasColumnName("media_type").HasMaxLength(50);
            b.Property(x => x.IsSensitive).HasColumnName("is_sensitive");
            b.Property(x => x.ExifMetadata).HasColumnName("exif_metadata").HasColumnType("jsonb");
            b.Property(x => x.DocumentType).HasColumnName("document_type").HasMaxLength(50);
            b.Property(x => x.VerificationStatus).HasColumnName("verification_status").HasMaxLength(50);
            b.Property(x => x.RejectedReason).HasColumnName("rejected_reason");
            b.Property(x => x.ReviewedByAdminId).HasColumnName("reviewed_by_admin_id");
            b.Property(x => x.ReviewedAt).HasColumnName("reviewed_at");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            // Bang media_assets khong co cot updated_at.
            b.Ignore(x => x.UpdatedAt);
        });

        modelBuilder.Entity<Address>(b =>
        {
            b.ToTable("addresses");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.OwnerUserId).HasColumnName("owner_user_id");
            b.Property(x => x.Label).HasColumnName("label").HasMaxLength(100);
            b.Property(x => x.FullAddress).HasColumnName("full_address");
            b.Property(x => x.Ward).HasColumnName("ward").HasMaxLength(100);
            b.Property(x => x.District).HasColumnName("district").HasMaxLength(100);
            b.Property(x => x.City).HasColumnName("city").HasMaxLength(100);
            b.Property(x => x.Country).HasColumnName("country").HasMaxLength(100);
            b.Property(x => x.PlaceId).HasColumnName("place_id").HasMaxLength(255);
            b.Property(x => x.Provider).HasColumnName("provider").HasMaxLength(50);
            b.Property(x => x.VerifiedAt).HasColumnName("verified_at");
            b.Property(x => x.Location).HasColumnName("location").HasColumnType("geography(Point,4326)");
            b.Property(x => x.Note).HasColumnName("note");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Ignore(x => x.IsVerified);
            // OMIT latitude & longitude: cot GENERATED ALWAYS AS (ST_Y/ST_X(location)) STORED,
            // không ghi được và suy ra từ Location nên không map vào entity.
        });

        modelBuilder.Entity<ServiceType>(b =>
        {
            b.ToTable("service_types");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.Code).HasColumnName("code").HasMaxLength(100);
            b.Property(x => x.Name).HasColumnName("name").HasMaxLength(255);
            b.Property(x => x.Description).HasColumnName("description");
            b.Property(x => x.DefaultDurationMinutes).HasColumnName("default_duration_minutes");
            b.Property(x => x.IsActive).HasColumnName("is_active");
            // Bang service_types khong co created_at/updated_at.
            b.Ignore(x => x.CreatedAt);
            b.Ignore(x => x.UpdatedAt);
        });

        modelBuilder.Entity<PricingRule>(b =>
        {
            b.ToTable("pricing_rules");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.Name).HasColumnName("name").HasMaxLength(255);
            b.Property(x => x.ServiceTypeId).HasColumnName("service_type_id");
            b.Property(x => x.BaseHourlyPrice).HasColumnName("base_hourly_price");
            b.Property(x => x.NightMultiplier).HasColumnName("night_multiplier").HasColumnType("numeric(5,2)");
            b.Property(x => x.HolidayMultiplier).HasColumnName("holiday_multiplier").HasColumnType("numeric(5,2)");
            b.Property(x => x.PlatformFeePercent).HasColumnName("platform_fee_percent").HasColumnType("numeric(5,2)");
            b.Property(x => x.DisputeWindowHours).HasColumnName("dispute_window_hours");
            b.Property(x => x.Holidays).HasColumnName("holidays").HasColumnType("jsonb");
            b.Property(x => x.CancellationPolicy).HasColumnName("cancellation_policy").HasColumnType("jsonb");
            b.Property(x => x.EffectiveFrom).HasColumnName("effective_from");
            b.Property(x => x.EffectiveTo).HasColumnName("effective_to");
            b.Property(x => x.IsActive).HasColumnName("is_active");
            b.Property(x => x.CreatedByAdminId).HasColumnName("created_by_admin_id");
            // Bang pricing_rules khong co created_at/updated_at (effective_from la field domain).
            b.Ignore(x => x.CreatedAt);
            b.Ignore(x => x.UpdatedAt);
        });
    }
}
