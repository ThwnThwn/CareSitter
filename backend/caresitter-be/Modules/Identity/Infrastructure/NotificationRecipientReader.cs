using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

/// <summary>Reads delivery addresses exclusively from the Identity-owned context.</summary>
internal sealed class NotificationRecipientReader(IdentityDbContext db) : INotificationRecipientReader
{
    /// <summary>Returns registered push tokens and the current account email for a service delivery.</summary>
    public async Task<NotificationRecipient> GetAsync(Guid userId, CancellationToken ct)
    {
        var account = await db.Users.Where(x => x.Id == userId)
            .Select(x => new { x.Email, x.NotificationPrefs }).SingleOrDefaultAsync(ct);
        var preferences = Application.NotificationPrefs.Parse(account?.NotificationPrefs);
        return new(
            account?.Email,
            await db.UserDevices.Where(x => x.UserId == userId && x.PushToken != null)
                .Select(x => x.PushToken!).Distinct().ToArrayAsync(ct),
            preferences.SupportChatMessage,
            preferences.ChatMessage);
    }
}
