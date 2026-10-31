using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task Push_disabled_still_creates_in_app_notification_and_dispatches_realtime()
    {
        await using var db = CreateDb();
        await ClearOutboxAsync(db);
        var seed = await SeedConversationWithMessagesAsync(db, 1, false);
        var messageId = await db.BookingChatMessages
            .Where(x => x.ConversationId == seed.ConversationId)
            .Select(x => x.Id)
            .SingleAsync();
        db.BookingChatOutbox.Add(BookingChatOutboxEvent.Create(
            seed.ConversationId, seed.EpochId, seed.CaregiverUserId,
            messageId, "USER_MESSAGE_CREATED", 2, DateTimeOffset.UtcNow));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var hub = new RecordingHubContext();
        var notifications = new RecordingNotificationService();
        using var meters = new ServiceCollection().AddMetrics().BuildServiceProvider();
        var dispatcher = CreateDispatcher(db, hub, notifications, meters,
            pushEnabled: false);

        Assert.Equal(1, await dispatcher.DispatchPendingAsync(20));
        Assert.Single(hub.Messages);
        var notification = Assert.Single(notifications.Attempts);
        Assert.Equal(seed.CaregiverUserId, notification.UserId);
        Assert.Equal("BOOKING_CHAT", notification.Type);
        Assert.False(notification.SendPush);
    }

    [PostgresFact]
    public async Task Only_opposite_recipient_user_message_requests_push()
    {
        await using var db = CreateDb();
        await ClearOutboxAsync(db);
        var seed = await SeedConversationWithMessagesAsync(db, 1, false);
        var messageId = await db.BookingChatMessages
            .Where(x => x.ConversationId == seed.ConversationId)
            .Select(x => x.Id)
            .SingleAsync();
        var now = DateTimeOffset.UtcNow;
        db.BookingChatOutbox.AddRange(
            BookingChatOutboxEvent.Create(seed.ConversationId, seed.EpochId,
                seed.CaregiverUserId, messageId, "USER_MESSAGE_CREATED", 2, now),
            BookingChatOutboxEvent.Create(seed.ConversationId, seed.EpochId,
                seed.CustomerId, messageId, "USER_MESSAGE_CREATED", 2, now),
            BookingChatOutboxEvent.Create(seed.ConversationId, seed.EpochId,
                seed.CaregiverUserId, null, "READ_CHANGED", 2, now),
            BookingChatOutboxEvent.Create(seed.ConversationId, seed.EpochId,
                seed.CaregiverUserId, null, "BOOKING_METADATA_CHANGED", 2, now));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var notifications = new RecordingNotificationService();
        using var meters = new ServiceCollection().AddMetrics().BuildServiceProvider();
        var dispatcher = CreateDispatcher(db, new RecordingHubContext(), notifications,
            meters, pushEnabled: true);

        Assert.Equal(4, await dispatcher.DispatchPendingAsync(20));
        var notification = Assert.Single(notifications.Attempts);
        Assert.Equal(seed.CaregiverUserId, notification.UserId);
        Assert.Equal("BOOKING_CHAT", notification.Type);
        Assert.DoesNotContain("Message 1", notification.Body ?? string.Empty);
    }

    [PostgresFact]
    public async Task Event_for_previous_caregiver_is_dropped_before_realtime_and_push()
    {
        await using var db = CreateDb();
        await ClearOutboxAsync(db);
        var seed = await SeedTwoEpochConversationAsync(db, 1, 1);
        var oldMessageId = await db.BookingChatMessages
            .Where(x => x.EpochId == seed.Epoch1Id)
            .Select(x => x.Id)
            .SingleAsync();
        var signal = BookingChatOutboxEvent.Create(seed.ConversationId, seed.Epoch1Id,
            seed.Caregiver1UserId, oldMessageId, "USER_MESSAGE_CREATED", 3,
            DateTimeOffset.UtcNow);
        db.BookingChatOutbox.Add(signal);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var hub = new RecordingHubContext();
        var notifications = new RecordingNotificationService();
        using var meters = new ServiceCollection().AddMetrics().BuildServiceProvider();
        var dispatcher = CreateDispatcher(db, hub, notifications, meters,
            pushEnabled: true);

        Assert.Equal(0, await dispatcher.DispatchPendingAsync(20));
        Assert.Empty(hub.Messages);
        Assert.Empty(notifications.Attempts);
        db.ChangeTracker.Clear();
        Assert.Equal("DROPPED", (await db.BookingChatOutbox
            .SingleAsync(x => x.EventId == signal.EventId)).Status);
    }

    [PostgresFact]
    public async Task Open_epoch_for_previous_caregiver_is_dropped_when_booking_assignment_changed()
    {
        await using var db = CreateDb();
        await ClearOutboxAsync(db);
        var seed = await SeedTwoEpochConversationAsync(db, 1, 1);
        await db.BookingChatEpochs.Where(x => x.Id == seed.Epoch2Id)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.EndedAt, DateTimeOffset.UtcNow));
        await db.BookingChatEpochs.Where(x => x.Id == seed.Epoch1Id)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.EndedAt, (DateTimeOffset?)null));
        var oldMessageId = await db.BookingChatMessages
            .Where(x => x.EpochId == seed.Epoch1Id)
            .Select(x => x.Id)
            .SingleAsync();
        var signal = BookingChatOutboxEvent.Create(seed.ConversationId, seed.Epoch1Id,
            seed.Caregiver1UserId, oldMessageId, "USER_MESSAGE_CREATED", 3,
            DateTimeOffset.UtcNow);
        db.BookingChatOutbox.Add(signal);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var hub = new RecordingHubContext();
        var notifications = new RecordingNotificationService();
        using var meters = new ServiceCollection().AddMetrics().BuildServiceProvider();
        var dispatcher = CreateDispatcher(db, hub, notifications, meters,
            pushEnabled: true);

        Assert.Equal(0, await dispatcher.DispatchPendingAsync(20));
        Assert.Empty(hub.Messages);
        Assert.Empty(notifications.Attempts);
        db.ChangeTracker.Clear();
        var persisted = await db.BookingChatOutbox
            .SingleAsync(x => x.EventId == signal.EventId);
        Assert.Equal("DROPPED", persisted.Status);
        Assert.Equal("epoch_not_current", persisted.LastError);
    }

    [PostgresFact]
    public async Task Retry_after_notification_failure_reuses_the_outbox_event_identity()
    {
        await using var db = CreateDb();
        await ClearOutboxAsync(db);
        var seed = await SeedConversationWithMessagesAsync(db, 1, false);
        var messageId = await db.BookingChatMessages
            .Where(x => x.ConversationId == seed.ConversationId)
            .Select(x => x.Id)
            .SingleAsync();
        var signal = BookingChatOutboxEvent.Create(seed.ConversationId, seed.EpochId,
            seed.CaregiverUserId, messageId, "USER_MESSAGE_CREATED", 2,
            DateTimeOffset.UtcNow);
        db.BookingChatOutbox.Add(signal);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var notifications = new RecordingNotificationService(failures: 1);
        using var meters = new ServiceCollection().AddMetrics().BuildServiceProvider();
        var dispatcher = CreateDispatcher(db, new RecordingHubContext(), notifications,
            meters, pushEnabled: true);

        Assert.Equal(0, await dispatcher.DispatchPendingAsync(20));
        await db.BookingChatOutbox.Where(x => x.EventId == signal.EventId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.AvailableAt, DateTimeOffset.UtcNow.AddSeconds(-1)));
        Assert.Equal(1, await dispatcher.DispatchPendingAsync(20));

        Assert.Equal(2, notifications.Attempts.Count);
        Assert.All(notifications.Attempts,
            message => Assert.Equal(signal.EventId, message.EventId));
        db.ChangeTracker.Clear();
        Assert.Equal("SENT", (await db.BookingChatOutbox
            .SingleAsync(x => x.EventId == signal.EventId)).Status);
    }

    private static Task<int> ClearOutboxAsync(BookingDbContext db) =>
        db.BookingChatOutbox.ExecuteDeleteAsync();

    private static BookingChatDispatcher CreateDispatcher(
        BookingDbContext db,
        IHubContext<CareTrackingHub> hub,
        IUserNotificationService notifications,
        IServiceProvider meters,
        bool pushEnabled) => new(
            db,
            hub,
            notifications,
            Options.Create(new BookingChatOptions
            {
                Enabled = true,
                PushEnabled = pushEnabled,
                DispatcherBatchSize = 20,
                DispatcherLeaseSeconds = 5,
                DispatcherMaxAttempts = 3,
                DispatcherRetryDelaySeconds = 1
            }),
            new BookingChatMetrics(meters.GetRequiredService<System.Diagnostics.Metrics.IMeterFactory>()),
            NullLogger<BookingChatDispatcher>.Instance);

    private sealed class RecordingNotificationService(int failures = 0)
        : IUserNotificationService
    {
        private int _remainingFailures = failures;
        public List<UserNotificationMessage> Attempts { get; } = [];

        public Task NotifyAsync(UserNotificationMessage message,
            CancellationToken ct = default)
        {
            Attempts.Add(message);
            if (_remainingFailures-- > 0)
                throw new TimeoutException("Injected notification timeout.");
            return Task.CompletedTask;
        }
    }

    private sealed class RecordingHubContext : IHubContext<CareTrackingHub>
    {
        private readonly RecordingClientProxy _client = new();
        public IHubClients Clients => new RecordingHubClients(_client);
        public IGroupManager Groups { get; } = new NoOpGroupManager();
        public IReadOnlyList<(string Method, object?[] Args)> Messages => _client.Messages;
    }

    private sealed class RecordingHubClients(IClientProxy client) : IHubClients
    {
        public IClientProxy All => client;
        public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => client;
        public IClientProxy Client(string connectionId) => client;
        public IClientProxy Clients(IReadOnlyList<string> connectionIds) => client;
        public IClientProxy Group(string groupName) => client;
        public IClientProxy GroupExcept(string groupName,
            IReadOnlyList<string> excludedConnectionIds) => client;
        public IClientProxy Groups(IReadOnlyList<string> groupNames) => client;
        public IClientProxy User(string userId) => client;
        public IClientProxy Users(IReadOnlyList<string> userIds) => client;
    }

    private sealed class RecordingClientProxy : IClientProxy
    {
        public List<(string Method, object?[] Args)> Messages { get; } = [];

        public Task SendCoreAsync(string method, object?[] args,
            CancellationToken cancellationToken = default)
        {
            Messages.Add((method, args));
            return Task.CompletedTask;
        }
    }

    private sealed class NoOpGroupManager : IGroupManager
    {
        public Task AddToGroupAsync(string connectionId, string groupName,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task RemoveFromGroupAsync(string connectionId, string groupName,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
    }
}
