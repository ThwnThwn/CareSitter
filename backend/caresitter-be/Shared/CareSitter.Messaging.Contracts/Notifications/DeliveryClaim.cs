namespace CareSitter.Messaging.Contracts.Notifications;

/// <summary>A private API response. Contents are fetched after claiming and never published to Kafka.</summary>
public sealed record DeliveryClaim(string Status, Guid? ClaimToken = null, string? Title = null,
    string? Body = null, Dictionary<string, string>? Data = null, string[]? PushTokens = null, string? Email = null);
