using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application.Chat;

public sealed record ChatActor(Guid UserId, bool IsAdmin, string Role);
public sealed record ChatCreateRequest(string Subject, string FirstMessage, Guid? BookingId);
public sealed record ChatMessageResponse(Guid Id, Guid ConversationId, long Sequence,
    Guid SenderUserId, string SenderRole, string Body, DateTimeOffset CreatedAt,
    Guid? ClientMessageId, bool Replayed = false);
public sealed record ChatConversationResponse(Guid Id, Guid TicketId, Guid OwnerUserId,
    Guid? BookingId, string Subject, string Status, Guid? AssignedAdminId,
    long TicketVersion, long ConversationVersion, long LastSequence,
    long OwnLastReadSequence, long StaffLastReadSequence, int UnreadCount,
    DateTimeOffset CreatedAt, DateTimeOffset? ClosedAt);
public sealed record ChatCreateResponse(ChatConversationResponse Conversation,
    ChatMessageResponse FirstMessage, bool Replayed);
public sealed record ChatPageResponse<T>(IReadOnlyList<T> Items, bool HasMore,
    long? NextBeforeSequence, long? NextAfterSequence, long HighWatermarkSequence);
public sealed record ChatActivityResponse(Guid Id, string Action, string? FromStatus,
    string? ToStatus, Guid? FromAdminId, Guid? ToAdminId, string? Reason,
    DateTimeOffset CreatedAt);
public sealed record ChatActivityListResponse(IReadOnlyList<ChatActivityResponse> Items,
    bool HasMore, DateTimeOffset? NextCreatedAt, Guid? NextId);
public sealed record ChatListResponse(IReadOnlyList<ChatConversationResponse> Items,
    bool HasMore, DateTimeOffset? NextCreatedAt, Guid? NextId);

public interface ISupportChatService
{
    Task<Result<ChatCreateResponse>> CreateAsync(ChatActor actor, Guid key,
        ChatCreateRequest request, CancellationToken ct);
    Task<Result<ChatListResponse>> ListAsync(ChatActor actor, string? queue,
        DateTimeOffset? beforeCreatedAt, Guid? beforeId, int limit, CancellationToken ct);
    Task<Result<ChatConversationResponse>> GetAsync(ChatActor actor, Guid id, CancellationToken ct);
    Task<Result<ChatPageResponse<ChatMessageResponse>>> MessagesAsync(ChatActor actor, Guid id,
        long? before, long? after, long? highWatermark, int limit, CancellationToken ct);
    Task<Result<ChatActivityListResponse>> ActivitiesAsync(ChatActor actor, Guid id,
        DateTimeOffset? beforeCreatedAt, Guid? beforeId, int limit, CancellationToken ct);
    Task<Result<ChatMessageResponse>> SendAsync(ChatActor actor, Guid id, Guid key,
        string body, CancellationToken ct);
    Task<Result<ChatConversationResponse>> ReadAsync(ChatActor actor, Guid id,
        long lastReadSequence, CancellationToken ct);
    Task<Result<ChatConversationResponse>> ClaimAsync(ChatActor actor, Guid id,
        long expectedVersion, CancellationToken ct);
    Task<Result<ChatConversationResponse>> TransferAsync(ChatActor actor, Guid id,
        Guid targetAdminId, bool takeover, long expectedVersion, string reason,
        CancellationToken ct);
    Task<Result<ChatConversationResponse>> StatusAsync(ChatActor actor, Guid id,
        string status, long expectedVersion, string reason, CancellationToken ct);
}
