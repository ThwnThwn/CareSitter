namespace CareSitter.Modules.Support.Application;

public sealed record NotificationInboxResponse(
    IReadOnlyList<NotificationInboxItem> Items, int UnreadCount, bool HasMore, string Version);
