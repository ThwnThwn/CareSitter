namespace CareSitter.Contracts.Services;

/// <summary>Identity-owned delivery addresses read through a public module boundary.</summary>
public interface INotificationRecipientReader
{
    /// <summary>Returns current delivery addresses without exposing Identity persistence.</summary>
    Task<NotificationRecipient> GetAsync(Guid userId, CancellationToken ct);
}

/// <summary>Private service-to-service recipient data; this snapshot must never enter Kafka.</summary>
public sealed record NotificationRecipient(string? Email, string[] PushTokens,
    bool SupportChatPushEnabled = true,
    bool ChatMessagePushEnabled = true);
