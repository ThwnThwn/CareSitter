using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class AccessSessionValidator(IdentityDbContext db) : IAccessSessionValidator
{
    public async Task<bool> IsActiveAsync(
        Guid userId,
        Guid sessionId,
        CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        return await db.Users.AsNoTracking().AnyAsync(
                   x => x.Id == userId && x.DeletedAt == null && x.Status == "ACTIVE", ct)
               && await db.RefreshTokenSessions.AsNoTracking().AnyAsync(
                   x => x.Id == sessionId && x.UserId == userId &&
                        x.RevokedAt == null && x.ExpiresAt > now, ct);
    }
}
