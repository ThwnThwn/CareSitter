using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Infrastructure.Persistence;

/// <summary>
/// Base DbContext cho moi module. Moi module map vao 1 schema rieng (vd "booking").
/// Tu dong set GUC `app.current_user_id` cho RLS khi co user trong request.
/// </summary>
public abstract class ModuleDbContext : DbContext
{
    private readonly ICurrentUser? _currentUser;

    protected ModuleDbContext(DbContextOptions options, ICurrentUser? currentUser)
        : base(options) => _currentUser = currentUser;

    /// <summary>Ten schema Postgres cua module (vd "identity", "booking").</summary>
    protected abstract string Schema { get; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(Schema);
        base.OnModelCreating(modelBuilder);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        UpdateTimestamps();
        await ApplyRlsContextAsync(cancellationToken);
        return await base.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Không dùng SaveChanges() đồng bộ — sẽ bỏ qua RLS context.
    /// Luôn dùng SaveChangesAsync để đảm bảo set_config được gọi trước khi ghi.
    /// </summary>
    [Obsolete("Dùng SaveChangesAsync để đảm bảo RLS context được thiết lập trước khi ghi.", error: true)]
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
        => throw new InvalidOperationException(
            "SaveChanges() đồng bộ không được phép trong ModuleDbContext vì sẽ bỏ qua RLS context. Dùng SaveChangesAsync().");

    /// <inheritdoc cref="SaveChanges(bool)"/>
    [Obsolete("Dùng SaveChangesAsync để đảm bảo RLS context được thiết lập trước khi ghi.", error: true)]
    public override int SaveChanges()
        => throw new InvalidOperationException(
            "SaveChanges() đồng bộ không được phép trong ModuleDbContext vì sẽ bỏ qua RLS context. Dùng SaveChangesAsync().");

    private void UpdateTimestamps()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            var createdAt = entry.Metadata.FindProperty(nameof(Entity.CreatedAt));
            var updatedAt = entry.Metadata.FindProperty(nameof(Entity.UpdatedAt));

            if (entry.State == EntityState.Added)
            {
                if (createdAt is not null && entry.Entity.CreatedAt == default)
                {
                    entry.Property(nameof(Entity.CreatedAt)).CurrentValue = now;
                }
                if (updatedAt is not null && entry.Entity.UpdatedAt == default)
                {
                    entry.Property(nameof(Entity.UpdatedAt)).CurrentValue = now;
                }
            }
            else if (entry.State == EntityState.Modified && updatedAt is not null)
            {
                entry.Property(nameof(Entity.UpdatedAt)).CurrentValue = now;
            }
        }
    }

    private async Task ApplyRlsContextAsync(CancellationToken ct)
    {
        if (_currentUser?.UserId is not { } userId)
            return;

        // Dùng false (session-level) thay SET LOCAL (transaction-local) để RLS context
        // có tác dụng kể cả khi SaveChangesAsync gọi ngoài outer transaction.
        // Connection pool tự reset session khi trả connection về pool;
        // không cần reset thủ công giữa các request.
        await Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {userId.ToString()}, false)", ct);
        await Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_role', {string.Join(',', _currentUser.Roles)}, false)", ct);
    }
}
