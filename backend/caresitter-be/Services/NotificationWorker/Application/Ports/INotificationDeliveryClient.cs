using CareSitter.Messaging.Contracts.Notifications;

namespace CareSitter.NotificationWorker.Application.Ports;

/// <summary>A private, idempotent API boundary owned by Support.</summary>
public interface INotificationDeliveryClient
{
    /// <summary>Claims one channel and retrieves the provider input associated with the trusted event.</summary>
    Task<DeliveryClaim> ClaimAsync(Guid eventId, Guid notificationId, Guid recipientId, string channel, CancellationToken ct);
    /// <summary>Records an outcome fenced by the claim token.</summary>
    Task<bool> CompleteAsync(Guid eventId, string channel, Guid token, bool success, string? failure, CancellationToken ct);
}
