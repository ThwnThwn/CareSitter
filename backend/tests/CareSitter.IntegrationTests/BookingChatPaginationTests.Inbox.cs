using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task Inbox_groups_chat_and_marks_only_the_displayed_conversation_through_its_head()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 3, false);
        var messages = await db.BookingChatMessages.Where(x => x.ConversationId == seed.ConversationId)
            .OrderBy(x => x.Sequence).Select(x => x.Id).ToListAsync();
        var actor = new TestActor(seed.CaregiverUserId, "CAREGIVER");
        var people = new TestPeople(seed.CaregiverProfileId, seed.CaregiverUserId, approved: true);
        await using var support = new SupportDbContext(
            new DbContextOptionsBuilder<SupportDbContext>().UseNpgsql(Database.ConnectionString).Options, actor);
        var store = new SupportNotificationInboxStore(support);
        var bookingReader = new BookingChatNotificationReader(db, actor, people,
            new InboxProfileReader(seed.CustomerId));
        var query = new ListNotificationInboxQueryHandler(store, bookingReader, actor);
        var candidates = new BookingChatNotificationGroup(Guid.NewGuid(), seed.BookingId, seed.ConversationId,
            [messages[0], messages[1]]);
        var legacy = new BookingChatNotificationGroup(Guid.NewGuid(), null, seed.ConversationId, [messages[0]]);
        var wrongThread = candidates with { Anchor = Guid.NewGuid(), ConversationId = Guid.NewGuid() };
        var previews = await bookingReader.ReadAsync([candidates, legacy, wrongThread]);
        Assert.Equal("Message 2", previews[candidates.Anchor].Body);
        Assert.Equal("Message 1", previews[legacy.Anchor].Body);
        Assert.DoesNotContain(wrongThread.Anchor, previews.Keys);
        var now = DateTimeOffset.UtcNow;

        // The earlier chat message reaches the inbox last after a delivery retry.
        var old = AddNotice(seed.CaregiverUserId, "BOOKING_CHAT", messages[1], now.AddMinutes(-3));
        var latest = AddNotice(seed.CaregiverUserId, "BOOKING_CHAT", messages[0], now.AddMinutes(-2));
        var booking = AddNotice(seed.CaregiverUserId, "BOOKING", messages[0], now.AddMinutes(-4));
        var other = AddNotice(seed.CustomerId, "BOOKING_CHAT", messages[0], now.AddMinutes(-1));
        await support.SaveChangesAsync();

        var firstPage = (await query.Handle(new(1, 1), default)).Value;
        var item = Assert.Single(firstPage.Items);
        Assert.Equal(latest.Id, item.Id);
        Assert.Equal(2, item.UnreadCount);
        Assert.Equal(3, firstPage.UnreadCount);
        Assert.True(firstPage.HasMore);
        Assert.Equal("Gia đình An", item.Chat?.SenderName);
        Assert.Equal("https://example.test/avatar.png", item.Chat?.SenderAvatarUrl);
        var newestMessage = await db.BookingChatMessages.SingleAsync(m => m.Id == messages[1]);
        Assert.Equal(newestMessage.BodySnapshot, item.Chat?.Preview);
        Assert.Equal(newestMessage.CreatedAt, item.Chat?.SentAt);
        Assert.NotNull(item.Chat?.ScheduledStart);
        var secondPage = (await query.Handle(new(2, 1), default)).Value;
        Assert.Equal(booking.Id, Assert.Single(secondPage.Items).Id);
        Assert.Equal(3, secondPage.UnreadCount);
        Assert.False(secondPage.HasMore);
        Assert.Equal(firstPage.Version, secondPage.Version);
        var pastEnd = (await query.Handle(new(3, 1), default)).Value;
        Assert.Empty(pastEnd.Items);
        Assert.Equal(firstPage.UnreadCount, pastEnd.UnreadCount);
        Assert.Equal(firstPage.Version, pastEnd.Version);

        var arrived = AddNotice(seed.CaregiverUserId, "BOOKING_CHAT", messages[2], now);
        await support.SaveChangesAsync();
        var beforeMark = (await query.Handle(new(1, 1), default)).Value;
        Assert.NotEqual(firstPage.Version, beforeMark.Version);
        var mark = new MarkNotificationGroupReadCommandHandler(store, actor);
        Assert.Equal(2, (await mark.Handle(new(latest.Id), default)).Value.Marked);
        Assert.Equal(0, (await mark.Handle(new(latest.Id), default)).Value.Marked);
        Assert.Equal(0, (await mark.Handle(new(other.Id), default)).Value.Marked);

        var updated = (await query.Handle(new(1, 2), default)).Value;
        Assert.Equal(arrived.Id, updated.Items[0].Id);
        Assert.Equal(1, updated.Items[0].UnreadCount);
        Assert.Equal(2, updated.UnreadCount);
        Assert.NotEqual(beforeMark.Version, updated.Version);
        Assert.NotNull((await support.Notifications.AsNoTracking().SingleAsync(x => x.Id == old.Id)).ReadAt);
        Assert.Null((await support.Notifications.AsNoTracking().SingleAsync(x => x.Id == other.Id)).ReadAt);

        Notification AddNotice(Guid userId, string type, Guid messageId, DateTimeOffset createdAt)
        {
            var notice = Notification.Create(userId, type, "Thông báo", "Nội dung push",
                JsonSerializer.Serialize(new
                {
                    bookingId = seed.BookingId,
                    conversationId = seed.ConversationId,
                    messageId
                })).Value;
            support.Notifications.Add(notice);
            support.Entry(notice).Property(n => n.CreatedAt).CurrentValue = createdAt;
            return notice;
        }
    }

    [PostgresFact]
    public async Task Inbox_preview_excludes_previous_caregiver_epoch_and_unrelated_recipient()
    {
        await using var db = CreateDb();
        var seed = await SeedTwoEpochConversationAsync(db, 1, 1);
        var ids = await db.BookingChatMessages.Where(x => x.ConversationId == seed.ConversationId)
            .OrderBy(x => x.Sequence).Select(x => x.Id).ToArrayAsync();
        var profiles = new InboxProfileReader(seed.CustomerId);
        var group = new BookingChatNotificationGroup(Guid.NewGuid(), null, seed.ConversationId, ids);
        var current = new BookingChatNotificationReader(db,
            new TestActor(seed.Caregiver2UserId, "CAREGIVER"),
            new TestPeople(seed.Caregiver2ProfileId, seed.Caregiver2UserId, approved: true), profiles);
        var visible = Assert.Single(await current.ReadAsync([group]));
        Assert.Equal(group.Anchor, visible.Key);
        Assert.Equal(await db.BookingChatMessages.Where(m => m.Id == ids[1]).Select(m => m.BodySnapshot).SingleAsync(),
            visible.Value.Body);

        var previous = new BookingChatNotificationReader(db,
            new TestActor(seed.Caregiver1UserId, "CAREGIVER"),
            new TestPeople(seed.Caregiver1ProfileId, seed.Caregiver1UserId, approved: true), profiles);
        Assert.Empty(await previous.ReadAsync([group]));
        var unrelated = new BookingChatNotificationReader(db,
            new TestActor(Guid.NewGuid(), "CUSTOMER"),
            new TestPeople(seed.Caregiver2ProfileId, seed.Caregiver2UserId, approved: true), profiles);
        Assert.Empty(await unrelated.ReadAsync([group]));
    }

    private sealed class InboxProfileReader(Guid senderId) : IUserProfileReader
    {
        public Task<string?> GetAvatarUrlAsync(Guid userId, CancellationToken ct = default) =>
            Task.FromResult<string?>(null);

        public Task<IReadOnlyDictionary<Guid, UserDisplayProfile>> GetDisplayProfilesAsync(
            IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyDictionary<Guid, UserDisplayProfile>>(
                userIds.Contains(senderId)
                    ? new Dictionary<Guid, UserDisplayProfile>
                    {
                        [senderId] = new("Gia đình An", "https://example.test/avatar.png")
                    }
                    : new Dictionary<Guid, UserDisplayProfile>());
    }
}
