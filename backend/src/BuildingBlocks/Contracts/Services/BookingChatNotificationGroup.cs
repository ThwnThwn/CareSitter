namespace CareSitter.Contracts.Services;

public sealed record BookingChatNotificationGroup(
    Guid Anchor, Guid? BookingId, Guid? ConversationId, Guid[] MessageIds);
