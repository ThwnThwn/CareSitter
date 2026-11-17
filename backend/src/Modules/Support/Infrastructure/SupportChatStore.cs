using CareSitter.Contracts.Services;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Persistence.Outbox;
using CareSitter.Modules.Support.Application.Chat;
using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportChatStore(
    SupportDbContext db, INotificationRecipientReader recipients, IConfiguration configuration,
    SupportChatResponses responses, MessagingSettings? messaging = null,
    IEventSerializer? serializer = null, OutboxWriter<SupportDbContext>? outbox = null) : ISupportChatStore
{
    public bool Enabled => configuration.GetValue<bool>("SupportChat:Enabled");

    public async Task<ISupportChatTransaction> BeginAsync(CancellationToken ct) =>
        new SupportChatTransaction(await db.Database.BeginTransactionAsync(ct));

    // Owner serialization protects the single-open-conversation invariant and create retries.
    public async Task LockOwnerAsync(Guid ownerId, CancellationToken ct) =>
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({ownerId.ToString()}, 0))", ct);

    public Task<ChatConversation?> FindCreatedAsync(Guid ownerId, Guid key, CancellationToken ct) =>
        db.ChatConversations.SingleOrDefaultAsync(x =>
            x.OwnerUserId == ownerId && x.CreateKey == key, ct);

    public Task<ChatMessage> FirstMessageAsync(Guid conversationId, CancellationToken ct) =>
        db.ChatMessages.AsNoTracking().SingleAsync(x =>
            x.ConversationId == conversationId && x.Sequence == 1, ct);

    public Task<SupportTicket> TicketAsync(Guid ticketId, CancellationToken ct) =>
        db.SupportTickets.AsNoTracking().SingleAsync(x => x.Id == ticketId, ct);

    public Task<ChatConversation?> OpenConversationAsync(Guid ownerId, CancellationToken ct) =>
        db.ChatConversations.AsNoTracking().FirstOrDefaultAsync(x =>
            x.OwnerUserId == ownerId && x.ClosedAt == null, ct);

    public Task<ChatMessage?> FindMessageAsync(Guid conversationId, Guid senderId, Guid key, CancellationToken ct) =>
        db.ChatMessages.AsNoTracking().SingleOrDefaultAsync(x =>
            x.ConversationId == conversationId && x.SenderUserId == senderId && x.IdempotencyKey == key, ct);

    public Task<ChatReadCursor?> ReadCursorAsync(Guid conversationId, Guid userId, CancellationToken ct) =>
        db.ChatReadCursors.SingleOrDefaultAsync(x =>
            x.ConversationId == conversationId && x.UserId == userId, ct);

    // Lock ticket before conversation so concurrent send, claim and close share one ordering.
    public async Task<(ChatConversation Conversation, SupportTicket Ticket)?> LockAsync(Guid id, CancellationToken ct)
    {
        var ticketId = await db.ChatConversations.AsNoTracking()
            .Where(x => x.Id == id).Select(x => (Guid?)x.TicketId).SingleOrDefaultAsync(ct);
        if (ticketId is null) return null;
        var ticket = await db.SupportTickets.FromSqlInterpolated(
            $"SELECT * FROM support.support_tickets WHERE id = {ticketId.Value} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (ticket is null) return null;
        var conversation = await db.ChatConversations.FromSqlInterpolated(
            $"SELECT * FROM support.chat_conversations WHERE id = {id} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        return conversation is null ? null : (conversation, ticket);
    }

    public void AddTicket(SupportTicket ticket) => db.SupportTickets.Add(ticket);
    public void AddConversation(ChatConversation conversation) => db.ChatConversations.Add(conversation);
    public void AddMessage(ChatMessage message) => db.ChatMessages.Add(message);
    public void AddNotification(Notification notification) => db.Notifications.Add(notification);
    public void AddReadCursor(ChatReadCursor cursor) => db.ChatReadCursors.Add(cursor);
    public void AddActivity(ChatActivityEvent activity) => db.ChatActivityEvents.Add(activity);
    public async Task SaveAsync(CancellationToken ct) => await db.SaveChangesAsync(ct);

    public Task<ChatConversationResponse> ResponseAsync(ChatConversation conversation, ChatActor actor, CancellationToken ct) =>
        responses.ToConversationAsync(conversation, actor, ct);

    public async Task EnqueuePushAsync(Guid ownerId, Guid notificationId, Guid messageId, DateTimeOffset now, CancellationToken ct)
    {
        if (!configuration.GetValue<bool>("SupportChat:PushEnabled")) return;
        var recipient = await recipients.GetAsync(ownerId, ct);
        if (!recipient.SupportChatPushEnabled || recipient.PushTokens.Length == 0) return;
        if (messaging is not { Enabled: true, NotificationsEnabled: true } ||
            serializer is null || outbox is null)
            throw new InvalidOperationException("SupportChat push requires the notification outbox.");
        var envelope = serializer.Create(new NotificationRequested(notificationId, ownerId, ["push"], "SUPPORT_CHAT"),
            new EventMetadata(messageId, now, messaging.Producer, ownerId.ToString(),
                System.Diagnostics.Activity.Current?.TraceId.ToString()));
        db.Set<NotificationDelivery>().Add(new NotificationDelivery
        {
            EventId = messageId, NotificationId = notificationId, Channel = "push"
        });
        outbox.Add(envelope);
    }
}
