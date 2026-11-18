using CareSitter.Modules.Support.Domain;

namespace CareSitter.Modules.Support.Application.Chat;

/// <summary>Persistence operations used within a single chat write transaction.</summary>
internal interface ISupportChatStore
{
    bool Enabled { get; }
    Task<ISupportChatTransaction> BeginAsync(CancellationToken ct);
    Task LockOwnerAsync(Guid ownerId, CancellationToken ct);
    Task<(ChatConversation Conversation, SupportTicket Ticket)?> LockAsync(Guid id, CancellationToken ct);
    Task<ChatConversation?> FindCreatedAsync(Guid ownerId, Guid key, CancellationToken ct);
    Task<ChatMessage> FirstMessageAsync(Guid conversationId, CancellationToken ct);
    Task<SupportTicket> TicketAsync(Guid ticketId, CancellationToken ct);
    Task<ChatConversation?> OpenConversationAsync(Guid ownerId, CancellationToken ct);
    Task<ChatMessage?> FindMessageAsync(Guid conversationId, Guid senderId, Guid key, CancellationToken ct);
    Task<ChatReadCursor?> ReadCursorAsync(Guid conversationId, Guid userId, CancellationToken ct);
    void AddTicket(SupportTicket ticket);
    void AddConversation(ChatConversation conversation);
    void AddMessage(ChatMessage message);
    void AddNotification(Notification notification);
    void AddReadCursor(ChatReadCursor cursor);
    void AddActivity(ChatActivityEvent activity);
    Task EnqueuePushAsync(Guid ownerId, Guid notificationId, Guid messageId, DateTimeOffset now, CancellationToken ct);
    Task SaveAsync(CancellationToken ct);
    Task<ChatConversationResponse> ResponseAsync(ChatConversation conversation, ChatActor actor, CancellationToken ct);
}
