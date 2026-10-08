namespace CareSitter.Messaging.Contracts.Events;

/// <summary>References a notification owned by Support. No message body or health data is transmitted.</summary>
public sealed record NotificationRequested(Guid NotificationId, Guid RecipientUserId,
    string[] Channels, string TemplateKey);
