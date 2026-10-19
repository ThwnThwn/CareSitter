using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatAdminService(
    BookingDbContext db,
    ICurrentUser currentUser,
    IBookingChatSupportTicketService? supportTickets = null)
    : IBookingChatAdminService
{
    public async Task<Result<BookingChatAdminListPage>> ListAsync(
        BookingChatAdminListFilter filter, string? cursor, int limit,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is null) return BookingChatErrors.Unauthenticated();
        if (!currentUser.IsInRole("ADMIN")) return BookingChatErrors.Forbidden();
        var size = Math.Clamp(limit, 1, 100);
        var query = db.BookingChatConversations.AsNoTracking();
        if (filter.BookingId is { } bookingId)
            query = query.Where(x => x.BookingId == bookingId);
        if (filter.Blocked is { } blocked)
            query = query.Where(x => (x.WriteBlockedAt != null) == blocked);
        if (filter.From is { } from)
            query = query.Where(x => x.UpdatedAt >= from);
        if (filter.To is { } to)
            query = query.Where(x => x.UpdatedAt <= to);
        if (filter.Reported is { } reported)
            query = query.Where(conversation => db.BookingChatReports.Any(report =>
                db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                    message.ConversationId == conversation.Id)) == reported);
        if (filter.DeadLetter is { } deadLetter)
            query = query.Where(conversation => db.BookingChatReports.Any(report =>
                report.Status == "DEAD_LETTER" && db.BookingChatMessages.Any(message =>
                    message.Id == report.MessageId && message.ConversationId == conversation.Id)) == deadLetter);
        if (filter.UserId is { } userId)
            query = query.Where(conversation =>
                db.Bookings.Any(booking => booking.Id == conversation.BookingId &&
                    booking.CustomerId == userId) ||
                db.BookingChatEpochs.Any(epoch => epoch.ConversationId == conversation.Id &&
                    epoch.CaregiverUserId == userId) ||
                db.BookingChatReports.Any(report => report.ReporterUserId == userId &&
                    db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                        message.ConversationId == conversation.Id)));
        if (cursor is not null)
        {
            if (!BookingChatAdminCursorCodec.TryDecode(cursor, out var updatedAt, out var id))
                return BookingChatErrors.CursorInvalid();
            query = query.Where(x => x.UpdatedAt < updatedAt ||
                x.UpdatedAt == updatedAt && x.Id.CompareTo(id) < 0);
        }
        var conversations = await query.OrderByDescending(x => x.UpdatedAt)
            .ThenByDescending(x => x.Id).Take(size + 1).ToListAsync(ct);
        var hasMore = conversations.Count > size;
        if (hasMore) conversations.RemoveAt(conversations.Count - 1);
        var nextCursor = hasMore && conversations.Count > 0
            ? BookingChatAdminCursorCodec.Encode(
                conversations[^1].UpdatedAt, conversations[^1].Id)
            : null;
        var ids = conversations.Select(x => x.Id).ToList();
        var reportCounts = await db.BookingChatMessages.AsNoTracking()
            .Where(message => ids.Contains(message.ConversationId))
            .Join(db.BookingChatReports.AsNoTracking(), message => message.Id,
                report => report.MessageId, (message, report) => new
                {
                    message.ConversationId,
                    report.Status
                })
            .GroupBy(x => x.ConversationId)
            .Select(group => new
            {
                ConversationId = group.Key,
                Count = group.Count(),
                DeadLetterCount = group.Count(x => x.Status == "DEAD_LETTER")
            })
            .ToDictionaryAsync(x => x.ConversationId, ct);
        return new BookingChatAdminListPage(conversations.Select(x =>
        {
            reportCounts.TryGetValue(x.Id, out var counts);
            return new BookingChatAdminListItem(x.Id, x.BookingId, x.ChangeVersion,
                x.LastSequence, x.LastMessageAt, x.WriteBlockedAt is not null,
                x.LegalHoldAt is not null && x.LegalHoldReleasedAt is null, x.UpdatedAt,
                counts?.Count ?? 0, counts?.DeadLetterCount ?? 0);
        }).ToList(), nextCursor);
    }

    public async Task<Result<BookingChatAdminDetail>> GetAsync(
        Guid conversationId, string reason, Guid? ticketId, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } adminId) return BookingChatErrors.Unauthenticated();
        if (!currentUser.IsInRole("ADMIN")) return BookingChatErrors.Forbidden();
        var auditReason = FormatReadReason(reason, ticketId);
        if (auditReason is null)
            return BookingChatErrors.InvalidRequest("Lý do đọc chi tiết phải từ 1 đến 500 ký tự.");
        var conversation = await db.BookingChatConversations.SingleOrDefaultAsync(x => x.Id == conversationId, ct);
        if (conversation is null) return BookingChatErrors.NotFound();
        db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(conversationId, adminId,
            "ADMIN_VIEWED", auditReason, DateTimeOffset.UtcNow));
        await db.SaveChangesAsync(ct);
        return ToDetail(conversation, await GetReportsAsync(conversation.Id, ct));
    }

    public async Task<Result<BookingChatAdminMessagePage>> GetMessagesAsync(
        Guid conversationId, long? beforeSequence, int limit, string reason, Guid? ticketId,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } adminId) return BookingChatErrors.Unauthenticated();
        if (!currentUser.IsInRole("ADMIN")) return BookingChatErrors.Forbidden();
        var auditReason = FormatReadReason(reason, ticketId);
        if (auditReason is null)
            return BookingChatErrors.InvalidRequest("Lý do đọc nội dung phải từ 1 đến 500 ký tự.");
        if (!await db.BookingChatConversations.AnyAsync(x => x.Id == conversationId, ct))
            return BookingChatErrors.NotFound();
        var size = Math.Clamp(limit, 1, 100);
        var query = db.BookingChatMessages.AsNoTracking().Where(x => x.ConversationId == conversationId);
        if (beforeSequence is { } before) query = query.Where(x => x.Sequence < before);
        var messages = await query.OrderByDescending(x => x.Sequence).Take(size + 1).ToListAsync(ct);
        var hasMore = messages.Count > size;
        if (hasMore) messages.RemoveAt(messages.Count - 1);
        long? nextBeforeSequence = hasMore && messages.Count > 0
            ? messages[^1].Sequence
            : null;
        messages.Reverse();
        db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(conversationId, adminId,
            "ADMIN_MESSAGES_VIEWED", auditReason, DateTimeOffset.UtcNow));
        await db.SaveChangesAsync(ct);
        return new BookingChatAdminMessagePage(messages.Select(x => new BookingChatAdminMessage(
            x.Id, x.EpochId, x.Sequence, x.SenderUserId, x.SenderRole, x.Kind,
            x.BodySnapshot, x.CreatedAt)).ToList(), nextBeforeSequence);
    }

    public async Task<Result<BookingChatAdminActivityPage>> GetActivityAsync(
        Guid conversationId, string? cursor, int limit, CancellationToken ct = default)
    {
        if (currentUser.UserId is null) return BookingChatErrors.Unauthenticated();
        if (!currentUser.IsInRole("ADMIN")) return BookingChatErrors.Forbidden();
        if (!await db.BookingChatConversations.AnyAsync(x => x.Id == conversationId, ct))
            return BookingChatErrors.NotFound();
        var size = Math.Clamp(limit, 1, 100);
        var query = db.BookingChatActivityEvents.AsNoTracking()
            .Where(x => x.ConversationId == conversationId);
        if (cursor is not null)
        {
            if (!BookingChatAdminCursorCodec.TryDecode(cursor, out var createdAt, out var id))
                return BookingChatErrors.CursorInvalid();
            query = query.Where(x => x.CreatedAt < createdAt ||
                x.CreatedAt == createdAt && x.Id.CompareTo(id) < 0);
        }
        var activities = await query.OrderByDescending(x => x.CreatedAt)
            .ThenByDescending(x => x.Id).Take(size + 1).ToListAsync(ct);
        var hasMore = activities.Count > size;
        if (hasMore) activities.RemoveAt(activities.Count - 1);
        var nextCursor = hasMore && activities.Count > 0
            ? BookingChatAdminCursorCodec.Encode(activities[^1].CreatedAt, activities[^1].Id)
            : null;
        return new BookingChatAdminActivityPage(activities.Select(x =>
            new BookingChatAdminActivity(x.Id, x.ActorUserId, x.Action, x.Reason, x.CreatedAt))
            .ToList(), nextCursor);
    }

    public Task<Result<BookingChatAdminDetail>> BlockAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, CancellationToken ct = default) =>
        MutateAsync(conversationId, request, true, false, ct);

    public Task<Result<BookingChatAdminDetail>> UnblockAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, CancellationToken ct = default) =>
        MutateAsync(conversationId, request, false, false, ct);

    public Task<Result<BookingChatAdminDetail>> ReleaseLegalHoldAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, CancellationToken ct = default) =>
        MutateAsync(conversationId, request, false, true, ct);

    private async Task<Result<BookingChatAdminDetail>> MutateAsync(Guid conversationId,
        BookingChatAdminBlockRequest request, bool block, bool releaseHold, CancellationToken ct)
    {
        if (currentUser.UserId is not { } adminId) return BookingChatErrors.Unauthenticated();
        if (!currentUser.IsInRole("ADMIN")) return BookingChatErrors.Forbidden();
        var reason = request.Reason?.Trim();
        if (string.IsNullOrWhiteSpace(reason) || reason.Length > 500)
            return BookingChatErrors.InvalidRequest("Lý do phải từ 1 đến 500 ký tự.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var bookingId = await db.BookingChatConversations.AsNoTracking()
            .Where(x => x.Id == conversationId).Select(x => (Guid?)x.BookingId)
            .SingleOrDefaultAsync(ct);
        if (bookingId is null) return BookingChatErrors.NotFound();
        // Preserve the booking → conversation lock order used by user chat writes.
        _ = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId.Value} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE id = {conversationId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotFound();
        if (conversation.ChangeVersion != request.ExpectedVersion)
            return BookingChatErrors.ScopeChanged();

        var now = DateTimeOffset.UtcNow;
        if (releaseHold)
        {
            var unresolvedStatuses = new[] { "PENDING", "PROCESSING", "FAILED", "DEAD_LETTER" };
            var unresolved = await db.BookingChatReports.AnyAsync(x => unresolvedStatuses.Contains(x.Status) &&
                db.BookingChatMessages.Any(m => m.Id == x.MessageId && m.ConversationId == conversationId), ct);
            if (unresolved)
                return Error.Conflict("booking.chat.legal_hold_active",
                    "Không thể gỡ legal hold khi còn báo cáo chưa được liên kết ticket.");
            var ticketIds = await db.BookingChatReports.AsNoTracking()
                .Where(report => report.Status == "LINKED" && report.SupportTicketId != null &&
                    db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                        message.ConversationId == conversationId))
                .Select(report => report.SupportTicketId!.Value)
                .Distinct()
                .ToListAsync(ct);
            if (ticketIds.Count > 0 &&
                (supportTickets is null || !await supportTickets.AreResolvedAsync(ticketIds, ct)))
                return Error.Conflict("booking.chat.legal_hold_active",
                    "Không thể gỡ legal hold khi ticket hỗ trợ vẫn đang xử lý.");
            conversation.ReleaseLegalHold(now);
        }
        else if (block)
        {
            conversation.BlockWrites(adminId, reason, now);
        }
        else
        {
            conversation.UnblockWrites(now);
        }

        db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(conversationId, adminId,
            releaseHold ? "LEGAL_HOLD_RELEASED" : block ? "WRITES_BLOCKED" : "WRITES_UNBLOCKED",
            reason, now));
        await EnqueueMetadataChangedAsync(conversation, now, ct);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ToDetail(conversation, await GetReportsAsync(conversation.Id, ct));
    }

    private async Task EnqueueMetadataChangedAsync(BookingChatConversation conversation,
        DateTimeOffset now, CancellationToken ct)
    {
        var booking = await db.Bookings.AsNoTracking().SingleAsync(x => x.Id == conversation.BookingId, ct);
        var epoch = await db.BookingChatEpochs.AsNoTracking().SingleOrDefaultAsync(
            x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (epoch is null) return;
        db.BookingChatOutbox.Add(BookingChatOutboxEvent.Create(conversation.Id, epoch.Id,
            booking.CustomerId, null, "METADATA_CHANGED", conversation.ChangeVersion, now));
        if (epoch.CaregiverUserId != booking.CustomerId)
            db.BookingChatOutbox.Add(BookingChatOutboxEvent.Create(conversation.Id, epoch.Id,
                epoch.CaregiverUserId, null, "METADATA_CHANGED", conversation.ChangeVersion, now));
    }

    private static BookingChatAdminDetail ToDetail(
        BookingChatConversation x, IReadOnlyList<BookingChatAdminReport> reports) => new(
        x.Id, x.BookingId, x.ChangeVersion, x.ScopeVersion, x.WriteBlockedAt is not null,
        x.WriteBlockReason, x.BlockedByUserId, x.LegalHoldAt, x.LegalHoldReason,
        x.LegalHoldReleasedAt, x.DisputeLockedAt, x.WriteClosesAt, x.PurgedAt, reports);

    private async Task<IReadOnlyList<BookingChatAdminReport>> GetReportsAsync(
        Guid conversationId, CancellationToken ct) =>
        await db.BookingChatReports.AsNoTracking()
            .Where(report => db.BookingChatMessages.Any(message =>
                message.Id == report.MessageId && message.ConversationId == conversationId))
            .OrderByDescending(report => report.CreatedAt)
            .Select(report => new BookingChatAdminReport(report.Id, report.MessageId,
                report.ReporterUserId, report.Reason, report.Status, report.SupportTicketId,
                report.Attempts, report.LastError, report.CreatedAt, report.UpdatedAt))
            .ToListAsync(ct);

    private static string? FormatReadReason(string? reason, Guid? ticketId)
    {
        var normalized = reason?.Trim();
        if (string.IsNullOrWhiteSpace(normalized) || normalized.Length > 500) return null;
        return ticketId is null ? normalized : $"{normalized} | ticket:{ticketId:D}";
    }
}
