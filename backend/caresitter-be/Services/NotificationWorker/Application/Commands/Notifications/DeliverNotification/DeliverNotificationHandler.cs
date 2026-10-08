using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.NotificationWorker.Application.Ports;

namespace CareSitter.NotificationWorker.Application.Commands.Notifications.DeliverNotification;

/// <summary>Delivers a requested channel through Support-owned claims, with no worker-owned inbox.</summary>
public sealed class DeliverNotificationHandler(INotificationDeliveryClient client, INotificationSender sender)
    : IEventHandler<NotificationRequested>
{
    /// <summary>Skips completed channels and retries busy or uncertain claims using the original event ID.</summary>
    public async Task<HandlerResult> HandleAsync(NotificationRequested message, EventContext context, CancellationToken ct)
    {
        if (message.NotificationId == Guid.Empty || message.RecipientUserId == Guid.Empty ||
            message.Channels is not { Length: > 0 and <= 2 } ||
            message.Channels.Any(x => x is not ("push" or "email")))
            return HandlerResult.Permanent("Invalid notification identity or channels.");
        foreach (var channel in message.Channels.Distinct())
        {
            var claim = await client.ClaimAsync(context.EventId, message.NotificationId, message.RecipientUserId, channel, ct);
            if (claim.Status == "Sent") continue;
            if (claim.Status == "Busy")
            {
                // Let an abandoned provider claim expire within the bounded consumer retry budget.
                await Task.Delay(TimeSpan.FromSeconds(10), ct);
                return HandlerResult.Transient("Delivery is leased by another attempt.");
            }
            if (claim.Status != "Acquired" || claim.ClaimToken is null)
                return HandlerResult.Permanent("The notification reference is invalid.");
            var result = await sender.SendAsync(channel, claim, ct);
            var completed = await client.CompleteAsync(context.EventId, channel, claim.ClaimToken.Value,
                result.Outcome == HandlerOutcome.Success, result.Reason, ct);
            if (!completed) return HandlerResult.Transient("The delivery claim could not be completed.");
            if (result.Outcome != HandlerOutcome.Success) return result;
        }
        return HandlerResult.Success();
    }
}
