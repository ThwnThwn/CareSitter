namespace CareSitter.Modules.Booking.Domain;

internal static class BookingChatRetentionPolicy
{
    public static bool CanPurge(
        BookingChatConversation conversation,
        DateTimeOffset now,
        bool hasUnresolvedReport,
        bool hasUnresolvedOutbox) =>
        conversation.PurgedAt is null &&
        conversation.RetainedUntil is not null && conversation.RetainedUntil <= now &&
        conversation.DisputeLockedAt is null &&
        (conversation.LegalHoldAt is null || conversation.LegalHoldReleasedAt is not null) &&
        (conversation.HoldUntil is null || conversation.HoldUntil <= now) &&
        !hasUnresolvedReport &&
        !hasUnresolvedOutbox;
}
