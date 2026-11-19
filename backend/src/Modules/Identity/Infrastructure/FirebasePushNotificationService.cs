using CareSitter.Contracts.Services;
using CareSitter.Push;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class FirebasePushNotificationService(
    IdentityDbContext db,
    IConfiguration configuration,
    ILogger<FirebasePushNotificationService> logger) : IPushNotificationService
{
    private readonly FirebasePushTransport _transport = new(configuration);

    public async Task SendToUserAsync(UserNotificationMessage message, IReadOnlySet<string> completed,
        Func<string[], CancellationToken, Task> checkpoint, CancellationToken ct = default)
    {
        var notificationPrefs = await db.Users.AsNoTracking()
            .Where(x => x.Id == message.UserId)
            .Select(x => x.NotificationPrefs)
            .SingleOrDefaultAsync(ct);
        var preferences = Application.NotificationPrefs.Parse(notificationPrefs);
        if ((message.Type == "BOOKING_CHAT" && !preferences.ChatMessage) ||
            (message.Type == "SUPPORT_CHAT" && !preferences.SupportChatMessage))
            return;

        var tokens = await db.UserDevices.AsNoTracking()
            .Where(x => x.UserId == message.UserId && x.PushToken != null)
            .Select(x => x.PushToken!)
            .Distinct()
            .ToListAsync(ct);

        if (tokens.Count == 0)
            return;

        var data = new Dictionary<string, string>(message.Data ?? new Dictionary<string, string>())
        {
            ["type"] = message.Type,
            ["eventId"] = (message.EventId ?? Guid.NewGuid()).ToString(),
            ["occurredAt"] = (message.OccurredAt ?? DateTimeOffset.UtcNow).ToString("O")
        };

        var result = await _transport.SendAsync(tokens.Where(t => !completed.Contains(PushTargetKey.FromToken(t))),
            message.Title, message.Body, data, checkpoint, ct);
        if (result.UnregisteredTokens.Count > 0)
        {
            var stale = result.UnregisteredTokens.ToArray();
            var devices = await db.UserDevices.Where(x => x.UserId == message.UserId && x.PushToken != null &&
                stale.Contains(x.PushToken)).ToListAsync(ct);
            db.UserDevices.RemoveRange(devices);
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Removed {Count} expired push registrations.", devices.Count);
        }
        if (result.Outcome != PushOutcome.Success)
            throw new InvalidOperationException($"Firebase delivery failed ({result.Outcome}).");
    }
}
