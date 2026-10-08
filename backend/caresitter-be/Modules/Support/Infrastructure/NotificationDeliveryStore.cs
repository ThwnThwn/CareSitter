using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.Modules.Support.Application.Ports;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

/// <summary>Claims persisted delivery state and reads private recipient data through Identity's port.</summary>
internal sealed class NotificationDeliveryStore(SupportDbContext db, INotificationRecipientReader recipients) : INotificationDeliveryStore
{
    /// <summary>Locks one delivery row; duplicate events return Sent or Busy instead of a second live claim.</summary>
    public async Task<DeliveryClaim> ClaimAsync(Guid eventId, Guid notificationId, Guid recipientId, string channel, CancellationToken ct)
    {
        string? title;
        string? body;
        Dictionary<string, string>? data;
        Guid token;
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var delivery = await db.Set<Domain.NotificationDelivery>().FromSqlInterpolated(
                $"SELECT * FROM support.notification_deliveries WHERE event_id = {eventId} AND channel = {channel} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (delivery is null || delivery.NotificationId != notificationId) return new("Missing");
            var notification = await db.Notifications.AsNoTracking().SingleOrDefaultAsync(x => x.Id == notificationId && x.UserId == recipientId, ct);
            if (notification is null) return new("Invalid");
            if (delivery.Status == "Sent") return new("Sent");
            if (delivery.LeaseUntil > DateTimeOffset.UtcNow) return new("Busy");
            token = Guid.NewGuid();
            delivery.ClaimToken = token;
            delivery.LeaseUntil = DateTimeOffset.UtcNow.AddSeconds(45);
            delivery.Status = "Sending";
            title = notification.Title;
            body = notification.Body;
            data = notification.Data is null ? [] : JsonSerializer.Deserialize<Dictionary<string, string>>(notification.Data);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        // Identity remains the sole owner of device tokens. This data never enters the event log.
        var recipient = await recipients.GetAsync(recipientId, ct);
        return new("Acquired", token, title, body, data, recipient.PushTokens, recipient.Email);
    }

    /// <summary>Uses the claim token as a fencing value; stale workers cannot complete a newer attempt.</summary>
    public async Task<bool> CompleteAsync(Guid eventId, string channel, Guid token, bool succeeded, string? failure, CancellationToken ct) =>
        await db.Database.ExecuteSqlInterpolatedAsync($"UPDATE support.notification_deliveries SET status = {(succeeded ? "Sent" : "Failed")}, sent_at = {(succeeded ? (DateTimeOffset?)DateTimeOffset.UtcNow : null)}, last_error = {failure}, lease_until = NULL, claim_token = NULL WHERE event_id = {eventId} AND channel = {channel} AND claim_token = {token}", ct) == 1;
}
