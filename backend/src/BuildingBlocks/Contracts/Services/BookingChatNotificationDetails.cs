namespace CareSitter.Contracts.Services;

public sealed record BookingChatNotificationDetails(
    Guid BookingId, Guid ConversationId, string? SenderName, string? SenderAvatarUrl,
    string Body, DateTimeOffset SentAt, DateTimeOffset ScheduledStart);
