using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application.BookingChat;

public sealed record BookingChatAdminListItem(
    Guid ConversationId, Guid BookingId, long ChangeVersion, long LastSequence,
    DateTimeOffset? LastMessageAt, bool WriteBlocked, bool LegalHoldActive,
    DateTimeOffset UpdatedAt, int ReportCount, int DeadLetterCount);

public sealed record BookingChatAdminReport(
    Guid Id, Guid MessageId, Guid ReporterUserId, string Reason, string Status,
    Guid? SupportTicketId, int Attempts, string? LastError, DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record BookingChatAdminDetail(
    Guid ConversationId, Guid BookingId, long ChangeVersion, long ScopeVersion,
    bool WriteBlocked, string? WriteBlockReason, Guid? BlockedByUserId,
    DateTimeOffset? LegalHoldAt, string? LegalHoldReason, DateTimeOffset? LegalHoldReleasedAt,
    DateTimeOffset? DisputeLockedAt, DateTimeOffset? WriteClosesAt, DateTimeOffset? PurgedAt,
    IReadOnlyList<BookingChatAdminReport> Reports);

public sealed record BookingChatAdminMessage(
    Guid Id, Guid EpochId, long Sequence, Guid? SenderUserId, string? SenderRole,
    string Kind, string Body, DateTimeOffset CreatedAt);

public sealed record BookingChatAdminActivity(
    Guid Id, Guid? ActorUserId, string Action, string? Reason, DateTimeOffset CreatedAt);

public sealed record BookingChatAdminListPage(
    IReadOnlyList<BookingChatAdminListItem> Items, string? NextCursor);

public sealed record BookingChatAdminMessagePage(
    IReadOnlyList<BookingChatAdminMessage> Items, long? NextBeforeSequence);

public sealed record BookingChatAdminActivityPage(
    IReadOnlyList<BookingChatAdminActivity> Items, string? NextCursor);

public sealed record BookingChatAdminBlockRequest(long ExpectedVersion, string Reason);

public sealed record BookingChatAdminListFilter(
    bool? Reported = null,
    bool? Blocked = null,
    bool? DeadLetter = null,
    Guid? BookingId = null,
    Guid? UserId = null,
    DateTimeOffset? From = null,
    DateTimeOffset? To = null);

public interface IBookingChatAdminService
{
    Task<Result<BookingChatAdminListPage>> ListAsync(
        BookingChatAdminListFilter filter, string? cursor, int limit,
        CancellationToken ct = default);
    Task<Result<BookingChatAdminDetail>> GetAsync(
        Guid conversationId, string reason, Guid? ticketId, CancellationToken ct = default);
    Task<Result<BookingChatAdminMessagePage>> GetMessagesAsync(Guid conversationId,
        long? beforeSequence, int limit, string reason, Guid? ticketId,
        CancellationToken ct = default);
    Task<Result<BookingChatAdminActivityPage>> GetActivityAsync(Guid conversationId,
        string? cursor, int limit, CancellationToken ct = default);
    Task<Result<BookingChatAdminDetail>> BlockAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, CancellationToken ct = default);
    Task<Result<BookingChatAdminDetail>> UnblockAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, CancellationToken ct = default);
    Task<Result<BookingChatAdminDetail>> ReleaseLegalHoldAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, CancellationToken ct = default);
}
