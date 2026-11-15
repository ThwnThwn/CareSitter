using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportChatMembership(SupportDbContext db, IActiveAdminLookup admins)
    : ISupportChatMembership
{
    public async Task<bool> CanReadAsync(Guid conversationId, Guid userId, bool isAdmin,
        CancellationToken ct = default)
    {
        if (isAdmin)
            return await admins.IsActiveAdminAsync(userId, ct) &&
                await db.ChatConversations.AsNoTracking().AnyAsync(x => x.Id == conversationId, ct);
        return await db.ChatConversations.AsNoTracking().AnyAsync(x =>
            x.Id == conversationId && x.OwnerUserId == userId, ct);
    }
}
