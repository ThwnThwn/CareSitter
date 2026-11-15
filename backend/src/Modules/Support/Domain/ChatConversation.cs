namespace CareSitter.Modules.Support.Domain;

public sealed class ChatConversation
{
    private ChatConversation() { }
    public Guid Id { get; private set; }
    public Guid TicketId { get; private set; }
    public Guid OwnerUserId { get; private set; }
    public Guid CreateKey { get; private set; }
    public string CreatePayloadHash { get; private set; } = string.Empty;
    public long LastSequence { get; private set; }
    public long StaffLastReadSequence { get; private set; }
    public long Version { get; private set; } = 1;
    public DateTimeOffset LastMessageAt { get; private set; }
    public DateTimeOffset? ClosedAt { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    public static ChatConversation Create(Guid ticketId, Guid ownerId, Guid key, string hash, DateTimeOffset now) => new()
    {
        Id = Guid.NewGuid(), TicketId = ticketId, OwnerUserId = ownerId,
        CreateKey = key, CreatePayloadHash = hash, LastMessageAt = now,
        CreatedAt = now, UpdatedAt = now
    };

    public long AddMessage(DateTimeOffset now)
    {
        LastSequence++;
        Version++;
        LastMessageAt = now;
        UpdatedAt = now;
        return LastSequence;
    }

    public void MarkRead(long sequence, bool isStaff, DateTimeOffset now)
    {
        if (isStaff && sequence > StaffLastReadSequence)
            StaffLastReadSequence = sequence;
        Version++;
        UpdatedAt = now;
    }

    public void Change(DateTimeOffset now, bool close)
    {
        Version++;
        UpdatedAt = now;
        if (close) ClosedAt ??= now;
    }
}

public sealed class ChatMessage
{
    private ChatMessage() { }
    public Guid Id { get; private set; }
    public Guid ConversationId { get; private set; }
    public long Sequence { get; private set; }
    public Guid SenderUserId { get; private set; }
    public string SenderRole { get; private set; } = string.Empty;
    public Guid IdempotencyKey { get; private set; }
    public string Body { get; private set; } = string.Empty;
    public string PayloadHash { get; private set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; private set; }

    public static ChatMessage Create(Guid conversationId, long sequence, Guid senderId,
        string role, Guid key, string body, string hash, DateTimeOffset now) => new()
        {
            Id = Guid.NewGuid(), ConversationId = conversationId, Sequence = sequence,
            SenderUserId = senderId, SenderRole = role, IdempotencyKey = key,
            Body = body, PayloadHash = hash, CreatedAt = now
        };
}

public sealed class ChatReadCursor
{
    public Guid ConversationId { get; set; }
    public Guid UserId { get; set; }
    public long LastReadSequence { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class ChatActivityEvent
{
    public Guid Id { get; set; }
    public Guid ConversationId { get; set; }
    public Guid ActorUserId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string? FromStatus { get; set; }
    public string? ToStatus { get; set; }
    public Guid? FromAdminId { get; set; }
    public Guid? ToAdminId { get; set; }
    public string? Reason { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
