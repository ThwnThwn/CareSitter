using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application.BookingChat;

public sealed record BookingChatTemplateResponse(
    string Key,
    int Version,
    string Body,
    IReadOnlyList<int>? AllowedMinutes = null);

public sealed record BookingChatMetadataResponse(
    bool FeatureEnabled,
    Guid BookingId,
    Guid? ConversationId,
    Guid? CurrentEpochId,
    long ScopeVersion,
    long ChangeVersion,
    string State,
    bool CanRead,
    bool CanSend,
    string ReadOnlyReason,
    DateTimeOffset ServerNow,
    DateTimeOffset? WriteClosesAt,
    long LastReadSequence,
    long OtherPartyLastReadSequence,
    int UnreadCount,
    bool IsBlockedByMe,
    bool IsBlockedByOther,
    IReadOnlyList<BookingChatTemplateResponse> QuickTemplates);

public sealed record BookingChatMessageResponse(
    Guid Id,
    Guid EpochId,
    long Sequence,
    Guid? SenderUserId,
    string? SenderRole,
    string Kind,
    string? TemplateKey,
    int? TemplateVersion,
    IReadOnlyDictionary<string, string>? TemplateParams,
    string Body,
    DateTimeOffset CreatedAt,
    bool IsMine);

public sealed record BookingChatMessagesResponse(
    IReadOnlyList<BookingChatMessageResponse> Items,
    string? NextCursor,
    string? PreviousCursor,
    bool HasMoreAfter,
    bool HasMoreBefore,
    long HighWatermark,
    long ScopeVersion);

public sealed record BookingChatSendRequest(
    Guid ExpectedEpochId,
    string Kind,
    string? Text,
    string? TemplateKey,
    int? TemplateVersion,
    IReadOnlyDictionary<string, string>? TemplateParams);

public sealed record BookingChatReadRequest(Guid EpochId, Guid LastReadMessageId);

public sealed record BookingChatReadResponse(
    Guid EpochId,
    long LastReadSequence,
    long ChangeVersion,
    bool Changed);

public sealed record BookingChatReportRequest(string Reason);

public sealed record BookingChatReportResponse(
    Guid ReportId,
    string Status,
    Guid? SupportTicketId);

public sealed record BookingChatBlockRequest(bool Blocked);

public sealed record BookingChatBlockResponse(
    bool IsBlockedByMe,
    bool Changed,
    DateTimeOffset? BlockedAt);

public interface IBookingChatService
{
    Task<Result<BookingChatMetadataResponse>> GetMetadataAsync(
        Guid bookingId, CancellationToken ct = default);

    Task<Result<BookingChatMessagesResponse>> GetMessagesAsync(
        Guid bookingId, string? afterCursor, string? beforeCursor, int limit,
        CancellationToken ct = default);

    Task<Result<BookingChatMessagesResponse>> ResumeMessagesAsync(
        Guid bookingId, Guid anchorMessageId, string direction, long scopeVersion,
        int limit, CancellationToken ct = default);

    Task<Result<BookingChatMessageResponse>> SendAsync(
        Guid bookingId, Guid idempotencyKey, BookingChatSendRequest request,
        CancellationToken ct = default);

    Task<Result<BookingChatReadResponse>> MarkReadAsync(
        Guid bookingId, BookingChatReadRequest request, CancellationToken ct = default);

    Task<Result<BookingChatReportResponse>> ReportMessageAsync(
        Guid bookingId, Guid messageId, BookingChatReportRequest request,
        CancellationToken ct = default);

    Task<Result<BookingChatReportResponse>> GetReportAsync(
        Guid bookingId, Guid reportId, CancellationToken ct = default);

    Task<Result<BookingChatBlockResponse>> SetBlockAsync(
        Guid bookingId, BookingChatBlockRequest request, CancellationToken ct = default);
}

internal static class BookingChatErrors
{
    public static Error Unauthenticated() =>
        Error.Unauthorized("booking.chat.unauthenticated", string.Empty);

    public static Error Forbidden() =>
        Error.Forbidden("booking.chat.forbidden", string.Empty);

    public static Error NotFound() =>
        Error.NotFound("booking.chat.not_found", string.Empty);

    public static Error Disabled() =>
        Error.Conflict("booking.chat.disabled", "Chat theo lịch hiện chưa được bật.");

    public static Error NotReady() =>
        Error.Conflict("booking.chat.not_ready", "Chat sẽ khả dụng sau khi caregiver nhận lịch.");

    public static Error ReadOnly(string reason) =>
        Error.Conflict("booking.chat.read_only", reason);

    public static Error ScopeChanged() =>
        Error.Conflict("booking.chat.scope_changed",
            "Lần phân công caregiver đã thay đổi. Vui lòng tải lại cuộc trò chuyện.");

    public static Error IdempotencyConflict() =>
        Error.Conflict("booking.chat.idempotency_conflict",
            "Idempotency-Key đã được dùng với nội dung khác.");

    public static Error CursorInvalid() =>
        Error.Conflict("booking.chat.cursor_invalid",
            "Cursor không còn hợp lệ. Vui lòng tải lại cuộc trò chuyện.");

    public static Error InvalidRequest(string message) =>
        Error.Validation("booking.chat.invalid_request", message);

    public static Error Purged() =>
        Error.Conflict("booking.chat.purged", "Nội dung cuộc trò chuyện đã hết thời hạn lưu trữ.");

    public static Error AlreadyReported() =>
        Error.Conflict("booking.chat.already_reported", "Bạn đã báo cáo tin nhắn này.");

    public static Error Blocked() =>
        Error.Conflict("booking.chat.blocked",
            "Không thể gửi tin nhắn khi một trong hai bên đang chặn cuộc trò chuyện.");
}
