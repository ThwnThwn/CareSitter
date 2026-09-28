using CareSitter.Infrastructure.Persistence;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

/// <summary>DbContext module Identity — schema "identity" (users, user_devices, audit_logs).</summary>
public sealed class IdentityDbContext : ModuleDbContext
{
    public const string SchemaName = "identity";

    public IdentityDbContext(DbContextOptions<IdentityDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<User> Users => Set<User>();
    public DbSet<UserDevice> UserDevices => Set<UserDevice>();
    public DbSet<RefreshTokenSession> RefreshTokenSessions => Set<RefreshTokenSession>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(b =>
        {
            b.ToTable("users");
            b.HasKey(x => x.Id);
            b.Ignore(x => x.DomainEvents);

            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(20);
            b.Property(x => x.Email).HasColumnName("email").HasMaxLength(255);
            b.Property(x => x.DisplayName).HasColumnName("display_name").HasMaxLength(255);
            b.Property(x => x.AvatarMediaId).HasColumnName("avatar_media_id");
            b.Property(x => x.AvatarUrl).HasColumnName("avatar_url").HasMaxLength(2048);
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(50);
            b.Property(x => x.Roles).HasColumnName("roles").HasColumnType("varchar[]");
            b.Property(x => x.FullName).HasColumnName("full_name").HasMaxLength(255);
            b.Property(x => x.DateOfBirth).HasColumnName("date_of_birth");
            b.Property(x => x.Gender).HasColumnName("gender").HasMaxLength(20);
            b.Property(x => x.DefaultAddressId).HasColumnName("default_address_id");
            b.Property(x => x.NotificationPrefs).HasColumnName("notification_prefs").HasColumnType("jsonb");
            b.Property(x => x.AdminDepartment).HasColumnName("admin_department").HasMaxLength(50);
            b.Property(x => x.AdminRole).HasColumnName("admin_role").HasMaxLength(50);
            b.Property(x => x.AdminPermissions).HasColumnName("admin_permissions").HasColumnType("jsonb");
            b.Property(x => x.AdminIsActive).HasColumnName("admin_is_active");
            b.Property(x => x.LastLoginAt).HasColumnName("last_login_at");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Property(x => x.DeletedAt).HasColumnName("deleted_at");
            b.Property(x => x.PasswordHash).HasColumnName("password_hash");
            b.Property(x => x.GoogleId).HasColumnName("google_id").HasMaxLength(255);
            b.HasIndex(x => x.GoogleId).IsUnique().HasFilter("google_id IS NOT NULL");
        });

        modelBuilder.Entity<UserDevice>(b =>
        {
            b.ToTable("user_devices");
            b.HasKey(x => x.Id);

            // Bang user_devices khong co updated_at.
            b.Ignore(x => x.UpdatedAt);

            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.Platform).HasColumnName("platform").HasMaxLength(20);
            b.Property(x => x.PushToken).HasColumnName("push_token");
            b.Property(x => x.DeviceName).HasColumnName("device_name").HasMaxLength(255);
            b.Property(x => x.BiometricEnabled).HasColumnName("biometric_enabled");
            b.Property(x => x.LastSeenAt).HasColumnName("last_seen_at");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.HasIndex(x => x.PushToken)
                .IsUnique()
                .HasFilter("push_token IS NOT NULL");
        });

        modelBuilder.Entity<AuditLog>(b =>
        {
            b.ToTable("audit_logs");
            b.HasKey(x => x.Id);

            // Bang audit_logs khong co updated_at.
            b.Ignore(x => x.UpdatedAt);

            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.ActorUserId).HasColumnName("actor_user_id");
            b.Property(x => x.ActorRole).HasColumnName("actor_role").HasMaxLength(50);
            b.Property(x => x.Action).HasColumnName("action").HasMaxLength(150);
            b.Property(x => x.EntityType).HasColumnName("entity_type").HasMaxLength(100);
            b.Property(x => x.EntityId).HasColumnName("entity_id");
            b.Property(x => x.BeforeData).HasColumnName("before_data").HasColumnType("jsonb");
            b.Property(x => x.AfterData).HasColumnName("after_data").HasColumnType("jsonb");
            // Dùng "text" thay vì "inet" vì Npgsql không tự convert C# string ↔ PostgreSQL inet.
            // Giá trị IP address vẫn được lưu đúng, chỉ mất validation kiểu inet ở DB level.
            b.Property(x => x.IpAddress).HasColumnName("ip_address").HasColumnType("text");
            b.Property(x => x.UserAgent).HasColumnName("user_agent");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
        });

        modelBuilder.Entity<RefreshTokenSession>(b =>
        {
            b.ToTable("refresh_tokens");
            b.HasKey(x => x.Id);
            b.Ignore(x => x.UpdatedAt);

            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.TokenHash).HasColumnName("token_hash").HasMaxLength(64);
            b.Property(x => x.DeviceId).HasColumnName("device_id").HasMaxLength(255);
            b.Property(x => x.DeviceInfo).HasColumnName("device_info").HasMaxLength(500);
            b.Property(x => x.IssuedAt).HasColumnName("issued_at");
            b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            b.Property(x => x.RevokedAt).HasColumnName("revoked_at");
            b.Property(x => x.ReplacedById).HasColumnName("replaced_by_id");
            b.Property(x => x.IpAddress).HasColumnName("ip_address").HasMaxLength(45);
            b.Property(x => x.CreatedAt).HasColumnName("created_at");

            b.HasIndex(x => x.TokenHash).IsUnique();
            b.HasIndex(x => x.UserId).HasFilter("revoked_at IS NULL");
            b.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            b.HasOne<RefreshTokenSession>().WithMany().HasForeignKey(x => x.ReplacedById)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }
}
