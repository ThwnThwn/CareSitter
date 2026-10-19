using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingChatRetentionPolicyTests
{
    [Fact]
    public void Expired_content_without_holds_can_be_purged()
    {
        var now = DateTimeOffset.UtcNow;
        var conversation = Expired(now);

        Assert.True(BookingChatRetentionPolicy.CanPurge(
            conversation, now, hasUnresolvedReport: false, hasUnresolvedOutbox: false));
    }

    [Fact]
    public void Dispute_legal_hold_and_unresolved_work_each_prevent_purge()
    {
        var now = DateTimeOffset.UtcNow;
        var dispute = Expired(now);
        dispute.LockForDispute(now.AddDays(-2));
        var legal = Expired(now);
        legal.PlaceLegalHold("Report", now.AddDays(-2));

        Assert.False(BookingChatRetentionPolicy.CanPurge(
            dispute, now, hasUnresolvedReport: false, hasUnresolvedOutbox: false));
        Assert.False(BookingChatRetentionPolicy.CanPurge(
            legal, now, hasUnresolvedReport: false, hasUnresolvedOutbox: false));
        Assert.False(BookingChatRetentionPolicy.CanPurge(
            Expired(now), now, hasUnresolvedReport: true, hasUnresolvedOutbox: false));
        Assert.False(BookingChatRetentionPolicy.CanPurge(
            Expired(now), now, hasUnresolvedReport: false, hasUnresolvedOutbox: true));
    }

    private static BookingChatConversation Expired(DateTimeOffset now)
    {
        var conversation = BookingChatConversation.Create(Guid.NewGuid(), now.AddDays(-200));
        conversation.ScheduleRetention(now.AddDays(-181), TimeSpan.FromDays(180));
        return conversation;
    }
}
