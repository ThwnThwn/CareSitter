using CareSitter.Modules.Booking.Application.BookingChat;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task User_block_prevents_both_sides_sending_until_unblocked()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 0, false);
        var customerChat = CreateChatService(db, seed.CustomerId, "CUSTOMER",
            seed.CaregiverProfileId, seed.CaregiverUserId);
        var caregiverChat = CreateChatService(db, seed.CaregiverUserId, "CAREGIVER",
            seed.CaregiverProfileId, seed.CaregiverUserId);

        var blocked = await customerChat.SetBlockAsync(
            seed.BookingId, new BookingChatBlockRequest(true));
        Assert.True(blocked.IsSuccess, blocked.Error.Message);
        Assert.True(blocked.Value.IsBlockedByMe);
        Assert.True(blocked.Value.Changed);

        var customerMetadata = await customerChat.GetMetadataAsync(seed.BookingId);
        var caregiverMetadata = await caregiverChat.GetMetadataAsync(seed.BookingId);
        Assert.True(customerMetadata.Value.IsBlockedByMe);
        Assert.False(customerMetadata.Value.IsBlockedByOther);
        Assert.False(customerMetadata.Value.CanSend);
        Assert.Equal("blocked_by_you", customerMetadata.Value.ReadOnlyReason);
        Assert.False(caregiverMetadata.Value.IsBlockedByMe);
        Assert.True(caregiverMetadata.Value.IsBlockedByOther);
        Assert.False(caregiverMetadata.Value.CanSend);
        Assert.Equal("blocked_by_other", caregiverMetadata.Value.ReadOnlyReason);

        var rejected = await caregiverChat.SendAsync(seed.BookingId, Guid.NewGuid(),
            new BookingChatSendRequest(seed.EpochId, "text", "Không được gửi", null, null, null));
        Assert.True(rejected.IsFailure);
        Assert.Equal("booking.chat.blocked", rejected.Error.Code);

        var unblocked = await customerChat.SetBlockAsync(
            seed.BookingId, new BookingChatBlockRequest(false));
        Assert.True(unblocked.IsSuccess, unblocked.Error.Message);
        Assert.True(unblocked.Value.Changed);
        Assert.False(unblocked.Value.IsBlockedByMe);

        var sent = await caregiverChat.SendAsync(seed.BookingId, Guid.NewGuid(),
            new BookingChatSendRequest(seed.EpochId, "text", "Đã gửi lại", null, null, null));
        Assert.True(sent.IsSuccess, sent.Error.Message);
        Assert.Equal(1, await db.BookingChatUserBlocks.CountAsync(x =>
            x.ConversationId == seed.ConversationId && x.UnblockedAt != null));
        Assert.Equal(2, await db.BookingChatActivityEvents.CountAsync(x =>
            x.ConversationId == seed.ConversationId &&
            (x.Action == "USER_BLOCKED" || x.Action == "USER_UNBLOCKED")));
    }
}
