using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts.Notifications;

namespace CareSitter.NotificationWorker.Application.Ports;

/// <summary>Sends one claimed channel without accessing module databases.</summary>
public interface INotificationSender
{
    /// <summary>Returns an explicit provider outcome; failures are never silently marked sent.</summary>
    Task<HandlerResult> SendAsync(string channel, DeliveryClaim claim, CancellationToken ct);
}
