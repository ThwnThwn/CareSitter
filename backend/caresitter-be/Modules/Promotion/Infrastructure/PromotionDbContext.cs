using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Persistence;
using CareSitter.Modules.Promotion.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Promotion.Infrastructure;

public sealed class PromotionDbContext : ModuleDbContext
{
    public const string SchemaName = "promotion";

    public PromotionDbContext(DbContextOptions<PromotionDbContext> options,
        ICurrentUser? currentUser = null) : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<Domain.Promotion> Promotions => Set<Domain.Promotion>();
    public DbSet<PromotionServiceScope> PromotionServiceScopes => Set<PromotionServiceScope>();
    public DbSet<PromotionRedemption> PromotionRedemptions => Set<PromotionRedemption>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Domain.Promotion>(b =>
        {
            b.ToTable("promotions");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.Code).HasColumnName("code").HasMaxLength(50);
            b.Property(x => x.Title).HasColumnName("title").HasMaxLength(160);
            b.Property(x => x.Summary).HasColumnName("summary").HasMaxLength(300);
            b.Property(x => x.Description).HasColumnName("description");
            b.Property(x => x.BadgeText).HasColumnName("badge_text").HasMaxLength(50);
            b.Property(x => x.TermsJson).HasColumnName("terms").HasColumnType("jsonb");
            b.Property(x => x.DiscountType).HasColumnName("discount_type")
                .HasConversion(v => v == PromotionDiscountType.Percentage ? "PERCENTAGE" : "FIXED_AMOUNT",
                    v => v == "PERCENTAGE" ? PromotionDiscountType.Percentage : PromotionDiscountType.FixedAmount);
            b.Property(x => x.DiscountValue).HasColumnName("discount_value");
            b.Property(x => x.MaxDiscountAmount).HasColumnName("max_discount_amount");
            b.Property(x => x.MinOrderAmount).HasColumnName("min_order_amount");
            b.Property(x => x.StartsAt).HasColumnName("starts_at");
            b.Property(x => x.EndsAt).HasColumnName("ends_at");
            b.Property(x => x.IsActive).HasColumnName("is_active");
            b.Property(x => x.FirstPaidBookingOnly).HasColumnName("first_paid_booking_only");
            b.Property(x => x.TotalUsageLimit).HasColumnName("total_usage_limit");
            b.Property(x => x.PerCustomerUsageLimit).HasColumnName("per_customer_usage_limit");
            b.Property(x => x.Priority).HasColumnName("priority");
            b.Property(x => x.IsFeatured).HasColumnName("is_featured");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.HasIndex(x => x.Code).IsUnique();
            b.Ignore(x => x.DomainEvents);
            b.HasMany(x => x.ServiceScopes).WithOne()
                .HasForeignKey(x => x.PromotionId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PromotionServiceScope>(b =>
        {
            b.ToTable("promotion_service_scopes");
            b.HasKey(x => new { x.PromotionId, x.ServiceTypeId });
            b.Property(x => x.PromotionId).HasColumnName("promotion_id");
            b.Property(x => x.ServiceTypeId).HasColumnName("service_type_id");
        });

        modelBuilder.Entity<PromotionRedemption>(b =>
        {
            b.ToTable("promotion_redemptions");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.PromotionId).HasColumnName("promotion_id");
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.DiscountAmount).HasColumnName("discount_amount");
            b.Property(x => x.Status).HasColumnName("status")
                .HasConversion(
                    v => v == PromotionRedemptionStatus.Reserved ? "RESERVED" :
                        v == PromotionRedemptionStatus.Redeemed ? "REDEEMED" : "RELEASED",
                    v => v == "RESERVED" ? PromotionRedemptionStatus.Reserved :
                        v == "REDEEMED" ? PromotionRedemptionStatus.Redeemed :
                        PromotionRedemptionStatus.Released)
                .HasMaxLength(20);
            b.Property(x => x.ReservedAt).HasColumnName("reserved_at");
            b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            b.Property(x => x.RedeemedAt).HasColumnName("redeemed_at");
            b.Property(x => x.ReleasedAt).HasColumnName("released_at");
            b.Property(x => x.ReleaseReason).HasColumnName("release_reason").HasMaxLength(100);
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.HasIndex(x => x.BookingId).IsUnique();
            b.HasIndex(x => new { x.PromotionId, x.CustomerId, x.Status });
        });
    }
}
