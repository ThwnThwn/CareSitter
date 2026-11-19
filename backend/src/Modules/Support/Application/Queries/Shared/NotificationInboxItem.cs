namespace CareSitter.Modules.Support.Application;

public sealed record NotificationInboxItem(
    Guid Id, string GroupKey, string Type, string Title, string? Body, string? Data,
    DateTimeOffset CreatedAt, int UnreadCount, NotificationChatPreview? Chat = null);
