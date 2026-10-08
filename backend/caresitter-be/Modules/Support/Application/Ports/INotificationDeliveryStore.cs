using CareSitter.Messaging.Contracts.Notifications;

namespace CareSitter.Modules.Support.Application.Ports;

/// <summary>Support-owned delivery persistence, independent of HTTP and EF Core adapters.</summary>
public interface INotificationDeliveryStore
{
    /// <summary>Claims a channel if the trusted event references the persisted recipient and notification.</summary>
    Task<DeliveryClaim> ClaimAsync(Guid eventId, Guid notificationId, Guid recipientId, string channel, CancellationToken ct);
    /// <summary>Records an outcome only for the current claim token.</summary>
    Task<bool> CompleteAsync(Guid eventId, string channel, Guid token, bool succeeded, string? failure, CancellationToken ct);
}
