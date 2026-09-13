using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Support.Application;

internal sealed class UserNotificationService(
    SupportDbContext db,
    IPushNotificationService push,
    ILogger<UserNotificationService> logger) : IUserNotificationService
{
    public async Task NotifyAsync(UserNotificationMessage message, CancellationToken ct = default)
    {
        var normalized = message with
        {
            EventId = message.EventId ?? Guid.NewGuid(),
            OccurredAt = message.OccurredAt ?? DateTimeOffset.UtcNow
        };
        var payload = new Dictionary<string, string>(
            normalized.Data ?? new Dictionary<string, string>())
        {
            ["eventId"] = normalized.EventId.Value.ToString(),
            ["occurredAt"] = normalized.OccurredAt.Value.ToString("O"),
            ["type"] = normalized.Type
        };

        try
        {
            var data = JsonSerializer.Serialize(payload);
            var notification = Notification.Create(
                normalized.UserId,
                normalized.Type,
                normalized.Title,
                normalized.Body,
                data);

            if (notification.IsSuccess)
            {
                db.Notifications.Add(notification.Value);
                await db.SaveChangesAsync(ct);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to persist notification for user {UserId}.", message.UserId);
        }

        await push.SendToUserAsync(normalized with { Data = payload }, ct);
    }
}
