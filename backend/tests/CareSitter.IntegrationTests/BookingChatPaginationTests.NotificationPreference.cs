using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task Booking_chat_delivery_honors_the_current_push_preference()
    {
        await using var bookingDb = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(bookingDb, 0, false);
        await using var db = new SupportDbContext(
            new DbContextOptionsBuilder<SupportDbContext>()
                .UseNpgsql(Database.ConnectionString).Options);
        var recipientId = seed.CustomerId;
        var eventId = Guid.NewGuid();
        var notification = Notification.Create(recipientId, "BOOKING_CHAT",
            "Tin nhắn mới", "Mở ứng dụng để xem.").Value;
        db.Notifications.Add(notification);
        db.Set<NotificationDelivery>().Add(new NotificationDelivery
        {
            EventId = eventId,
            NotificationId = notification.Id,
            Channel = "push"
        });
        await db.SaveChangesAsync();

        var store = new NotificationDeliveryStore(db,
            new NotificationRecipientReaderStub(chatMessagePushEnabled: false));
        var claim = await store.ClaimAsync(eventId, notification.Id, recipientId,
            "push", CancellationToken.None);

        Assert.Equal("Acquired", claim.Status);
        Assert.Empty(claim.PushTokens ?? []);
    }

    private sealed class NotificationRecipientReaderStub(bool chatMessagePushEnabled)
        : INotificationRecipientReader
    {
        public Task<NotificationRecipient> GetAsync(Guid userId, CancellationToken ct) =>
            Task.FromResult(new NotificationRecipient(null, ["device-token"],
                ChatMessagePushEnabled: chatMessagePushEnabled));
    }
}
