using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.Modules.Support.Application.Ports;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Notifications.ClaimNotificationDelivery;

/// <summary>Delegates claim authorization and atomic state transition to the owning persistence port.</summary>
internal sealed class ClaimNotificationDeliveryCommandHandler(INotificationDeliveryStore store)
    : IRequestHandler<ClaimNotificationDeliveryCommand, DeliveryClaim>
{
    /// <summary>Rejects invalid identities/channels before accessing delivery state.</summary>
    public Task<DeliveryClaim> Handle(ClaimNotificationDeliveryCommand request, CancellationToken ct) =>
        request.EventId == Guid.Empty || request.NotificationId == Guid.Empty || request.RecipientId == Guid.Empty ||
        request.Channel is not ("push" or "email") ? Task.FromResult(new DeliveryClaim("Invalid")) :
        store.ClaimAsync(request.EventId, request.NotificationId, request.RecipientId, request.Channel, ct);
}
