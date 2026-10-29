using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresTheory]
    [InlineData("before", 25)]
    [InlineData("after", 76)]
    public async Task Firestore_resume_preserves_the_message_anchor_and_returns_API_cursors(
        string direction, int firstSequence)
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 125, jumbleTimestamps: true);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER",
            seed.CaregiverProfileId, seed.CaregiverUserId);
        var anchor = await db.BookingChatMessages.Where(message =>
            message.ConversationId == seed.ConversationId && message.Sequence == 75)
            .Select(message => message.Id).SingleAsync();

        var result = await chat.ResumeMessagesAsync(seed.BookingId, anchor, direction, 1, 50);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(Enumerable.Range(firstSequence, 50).Select(value => (long)value),
            result.Value.Items.Select(message => message.Sequence));
        Assert.NotNull(result.Value.NextCursor);
        var continuation = await chat.GetMessagesAsync(seed.BookingId,
            result.Value.NextCursor, null, 50);
        Assert.True(continuation.IsSuccess, continuation.Error.Message);
    }

    [PostgresFact]
    public async Task Firestore_resume_rejects_other_users_other_conversations_and_stale_scopes()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 5, jumbleTimestamps: false);
        var other = await SeedConversationWithMessagesAsync(db, 5, jumbleTimestamps: false);
        var anchor = await db.BookingChatMessages.Where(message =>
            message.ConversationId == seed.ConversationId && message.Sequence == 2)
            .Select(message => message.Id).SingleAsync();
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER",
            seed.CaregiverProfileId, seed.CaregiverUserId);
        var outsider = CreateChatService(db, Guid.NewGuid(), "CUSTOMER",
            seed.CaregiverProfileId, seed.CaregiverUserId);

        Assert.Equal("booking.chat.not_found",
            (await outsider.ResumeMessagesAsync(seed.BookingId, anchor, "after", 1, 50)).Error.Code);
        Assert.Equal("booking.chat.cursor_invalid",
            (await chat.ResumeMessagesAsync(other.BookingId, anchor, "after", 1, 50)).Error.Code);
        Assert.Equal("booking.chat.scope_changed",
            (await chat.ResumeMessagesAsync(seed.BookingId, anchor, "after", 2, 50)).Error.Code);
    }
}
