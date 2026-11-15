using CareSitter.Messaging.Contracts.Notifications;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Notifications.ClaimNotificationDelivery;

/// <summary>Claims delivery of an existing notification through a trusted service boundary.</summary>
public sealed record ClaimNotificationDeliveryCommand(Guid EventId, Guid NotificationId,
    Guid RecipientId, string Channel) : IRequest<DeliveryClaim>;
