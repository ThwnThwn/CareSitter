using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class UserProfileReader(IdentityDbContext db) : IUserProfileReader
{
    public Task<string?> GetAvatarUrlAsync(Guid userId, CancellationToken ct = default) =>
        db.Users.AsNoTracking()
            .Where(x => x.Id == userId && x.DeletedAt == null)
            .Select(x => x.AvatarUrl)
            .FirstOrDefaultAsync(ct);
}
