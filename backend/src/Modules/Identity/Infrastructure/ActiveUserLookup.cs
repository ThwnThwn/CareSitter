using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class ActiveUserLookup(IdentityDbContext db) : IActiveUserLookup
{
    public async Task<bool> IsActiveWithAnyRoleAsync(
        Guid userId,
        IReadOnlyCollection<string> roles,
        CancellationToken ct = default)
    {
        if (roles.Count == 0) return false;
        var user = await db.Users.AsNoTracking()
            .Where(value => value.Id == userId && value.DeletedAt == null)
            .Select(value => new { value.Status, value.Roles })
            .SingleOrDefaultAsync(ct);
        return user is { Status: "ACTIVE" } &&
            user.Roles.Any(role => roles.Contains(role, StringComparer.OrdinalIgnoreCase));
    }
}
