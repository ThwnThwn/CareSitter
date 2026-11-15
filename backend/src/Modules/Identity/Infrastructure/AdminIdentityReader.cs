using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class AdminIdentityReader(IdentityDbContext db) : IAdminIdentityReader
{
    public Task<int> CountActiveUsersAsync(CancellationToken ct = default) =>
        db.Users.AsNoTracking()
            .CountAsync(x => x.DeletedAt == null && x.Status == "ACTIVE", ct);

    public Task<AdminUserProfile?> FindUserAsync(Guid userId, CancellationToken ct = default) =>
        db.Users.AsNoTracking()
            .Where(x => x.Id == userId && x.DeletedAt == null)
            .Select(x => new AdminUserProfile(
                x.Id,
                x.Email,
                x.DisplayName,
                x.FullName,
                x.Roles,
                x.AdminDepartment))
            .SingleOrDefaultAsync(ct);
}
