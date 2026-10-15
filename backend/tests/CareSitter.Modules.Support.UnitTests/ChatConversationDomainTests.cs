using CareSitter.Modules.Support.Domain;

namespace CareSitter.Modules.Support.UnitTests;

public sealed class ChatConversationDomainTests
{
    [Fact]
    public void Messages_have_monotonic_sequence_and_read_receipt_never_moves_back()
    {
        var now = DateTimeOffset.UtcNow;
        var conversation = ChatConversation.Create(Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), new string('a', 64), now);

        Assert.Equal(1, conversation.AddMessage(now));
        Assert.Equal(2, conversation.AddMessage(now));
        conversation.MarkRead(2, true, now);
        conversation.MarkRead(1, true, now);

        Assert.Equal(2, conversation.LastSequence);
        Assert.Equal(2, conversation.StaffLastReadSequence);
        Assert.Equal(5, conversation.Version);
    }

    [Fact]
    public void Owner_read_advances_version_without_creating_staff_receipt()
    {
        var now = DateTimeOffset.UtcNow;
        var conversation = ChatConversation.Create(Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), new string('a', 64), now);
        conversation.AddMessage(now);

        conversation.MarkRead(1, false, now);

        Assert.Equal(0, conversation.StaffLastReadSequence);
        Assert.Equal(3, conversation.Version);
    }
}
