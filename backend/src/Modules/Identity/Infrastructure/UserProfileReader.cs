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

    public async Task<IReadOnlyDictionary<Guid, UserDisplayProfile>> GetDisplayProfilesAsync(
        IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) =>
        await db.Users.AsNoTracking()
            .Where(x => userIds.Contains(x.Id) && x.DeletedAt == null)
            .Select(x => new { x.Id, x.DisplayName, x.FullName, x.AvatarUrl })
            .ToDictionaryAsync(x => x.Id,
                x => new UserDisplayProfile(x.DisplayName ?? x.FullName, x.AvatarUrl), ct);
}
