namespace CareSitter.Modules.Support.Controllers.Contracts.Notifications;

/// <summary>The internal HTTP claim payload mapped to a mediator command.</summary>
public sealed record ClaimNotificationDeliveryRequest(Guid EventId, Guid NotificationId, Guid RecipientId, string Channel);
