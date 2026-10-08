namespace CareSitter.Modules.Support.Controllers.Contracts.Notifications;

/// <summary>The internal HTTP completion payload mapped to a mediator command.</summary>
public sealed record CompleteNotificationDeliveryRequest(Guid EventId, string Channel, Guid ClaimToken, bool Succeeded, string? Failure);
