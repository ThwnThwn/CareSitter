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
        try
        {
            var data = message.Data is null ? null : JsonSerializer.Serialize(message.Data);
            var notification = Notification.Create(
                message.UserId,
                message.Type,
                message.Title,
                message.Body,
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

        await push.SendToUserAsync(message, ct);
    }
}
