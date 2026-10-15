using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class ActiveAdminLookup(IdentityDbContext db) : IActiveAdminLookup
{
    public async Task<bool> IsActiveAdminAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await db.Users.AsNoTracking().Where(x => x.Id == userId)
            .Select(x => new { x.Status, x.Roles, x.AdminIsActive })
            .SingleOrDefaultAsync(ct);
        return user is { Status: "ACTIVE" } && user.Roles.Contains("ADMIN") &&
            user.AdminIsActive != false;
    }
}
