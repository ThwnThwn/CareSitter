using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using Microsoft.Extensions.Logging;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class UserNotificationService(
    SupportDbContext db,
    IPushNotificationService push,
    ILogger<UserNotificationService> logger,
    MessagingSettings? messaging = null,
    IEventSerializer? serializer = null,
    OutboxWriter<SupportDbContext>? outbox = null) : IUserNotificationService
{
    /// <summary>Persists a notification and its Kafka request atomically when the flow is enabled.</summary>
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

        if (messaging is { Enabled: true, NotificationsEnabled: true })
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            // Serialize retries of the same event before creating the notification and outbox row.
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(hashtextextended({normalized.EventId!.Value.ToString()}, 0))", ct);
            var existing = await db.Set<NotificationDelivery>().Where(x => x.EventId == normalized.EventId.Value)
                .Select(x => (Guid?)x.NotificationId).FirstOrDefaultAsync(ct);
            if (existing is { } notificationId)
            {
                if (!await db.Notifications.AnyAsync(x => x.Id == notificationId && x.UserId == normalized.UserId, ct))
                    throw new InvalidOperationException("The event identity belongs to a different recipient.");
                await transaction.CommitAsync(ct);
                return;
            }
            var notification = Notification.Create(normalized.UserId, normalized.Type, normalized.Title,
                normalized.Body, JsonSerializer.Serialize(payload));
            if (notification.IsFailure) throw new InvalidOperationException("Invalid notification request.");
            // Kafka carries IDs only. Content and device tokens stay behind private API endpoints.
            var envelope = serializer!.Create(new NotificationRequested(notification.Value.Id, normalized.UserId,
                ["push"], normalized.Type), new EventMetadata(normalized.EventId!.Value,
                normalized.OccurredAt!.Value.ToUniversalTime(), messaging.Producer, normalized.UserId.ToString(),
                System.Diagnostics.Activity.Current?.TraceId.ToString()));
            db.Notifications.Add(notification.Value);
            db.Set<NotificationDelivery>().Add(new NotificationDelivery
            { EventId = envelope.EventId, NotificationId = notification.Value.Id, Channel = "push" });
            outbox!.Add(envelope);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return;
        }

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
