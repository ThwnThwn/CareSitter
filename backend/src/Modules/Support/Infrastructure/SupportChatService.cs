using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Chat;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Persistence.Outbox;
using CareSitter.Infrastructure.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Support.Infrastructure;

/// <summary>
/// Owns ticket/chat transactions. Mutations lock ticket before conversation so
/// send, claim and close observe one committed order.
/// </summary>
internal sealed class SupportChatService(
    SupportDbContext db, IBookingPartyAccess bookingAccess, IActiveAdminLookup admins,
    INotificationRecipientReader recipients, IConfiguration configuration,
    IHubContext<SupportChatHub> hub, ILogger<SupportChatService> logger,
    MessagingSettings? messaging = null, IEventSerializer? serializer = null,
    OutboxWriter<SupportDbContext>? outbox = null,
    SupportChatMetrics? metrics = null)
    : ISupportChatService
{
    private bool Enabled => configuration.GetValue<bool>("SupportChat:Enabled");
    private static readonly Error Missing = Error.NotFound("support.chat.not_found", "Không tìm thấy hội thoại.");
    private static readonly Error Disabled = Error.Unavailable("support.chat.disabled", "Chat hỗ trợ đang tạm dừng.");

    public async Task<Result<ChatCreateResponse>> CreateAsync(ChatActor actor, Guid key,
        ChatCreateRequest request, CancellationToken ct)
    {
        if (!Enabled) return Disabled;
        if (actor.IsAdmin || actor.Role is not ("CUSTOMER" or "CAREGIVER"))
            return Error.Forbidden("support.chat.forbidden", "Vai trò không được tạo hội thoại.");
        if (key == Guid.Empty) return Invalid("Idempotency-Key phải là UUID khác rỗng.");
        var subject = request.Subject?.Trim() ?? string.Empty;
        var body = Normalize(request.FirstMessage);
        if (subject.Length is < 3 or > 255 || body.Length is < 10 or > 2000)
            return Invalid("Tiêu đề cần 3–255 ký tự và tin đầu cần 10–2.000 ký tự.");
        var hash = Hash($"{subject.Length}:{subject}|{body.Length}:{body}|{request.BookingId}");
        // Validate context before entering a transaction; never trust a booking ID supplied by a client.
        if (request.BookingId is { } bookingId &&
            !await bookingAccess.IsPartyAsync(bookingId, actor.UserId, ct)) return Missing;

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({actor.UserId.ToString()}, 0))", ct);
        var prior = await db.ChatConversations.SingleOrDefaultAsync(x =>
            x.OwnerUserId == actor.UserId && x.CreateKey == key, ct);
        if (prior is not null)
        {
            if (prior.CreatePayloadHash != hash) return Conflict("idempotency_conflict", "Khóa đã dùng cho nội dung khác.");
            metrics?.Replayed("create");
            var first = await db.ChatMessages.AsNoTracking().SingleAsync(x =>
                x.ConversationId == prior.Id && x.Sequence == 1, ct);
            var originalTicket = await db.SupportTickets.AsNoTracking()
                .SingleAsync(x => x.Id == prior.TicketId, ct);
            var original = new ChatConversationResponse(prior.Id, originalTicket.Id,
                prior.OwnerUserId, originalTicket.BookingId, originalTicket.Title,
                "NEW", null, 1, 2, 1, 0, 0, 0, prior.CreatedAt, null);
            return new ChatCreateResponse(original,
                ToMessage(first, actor.UserId, true), true);
        }
        var open = await db.ChatConversations.AsNoTracking().FirstOrDefaultAsync(x =>
            x.OwnerUserId == actor.UserId && x.ClosedAt == null, ct);
        if (open is not null)
            return Conflict("open_conversation_exists", $"Đã có hội thoại mở: {open.Id}");

        var ticketResult = SupportTicket.Create(actor.UserId, "GENERAL", "MEDIUM",
            request.BookingId, subject, body, "[]");
        if (ticketResult.IsFailure) return ticketResult.Error;
        var now = DateTimeOffset.UtcNow;
        var ticket = ticketResult.Value;
        var conversation = ChatConversation.Create(ticket.Id, actor.UserId, key, hash, now);
        var message = ChatMessage.Create(conversation.Id, conversation.AddMessage(now),
            actor.UserId, actor.Role, key, body, Hash(body), now);
        db.SupportTickets.Add(ticket);
        db.ChatConversations.Add(conversation);
        db.ChatMessages.Add(message);
        AddActivity(conversation.Id, actor.UserId, "CREATED", null, "NEW", null, null, null, now);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        metrics?.Created();
        metrics?.MessageCommitted(actor.Role);
        await SignalAsync(SupportChatHub.AdminQueueGroup, "AdminQueueChanged", new
        {
            conversationId = conversation.Id, changeType = "CREATED",
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });
        return new ChatCreateResponse(await ToConversationAsync(conversation, actor, ct),
            ToMessage(message, actor.UserId), false);
    }

    public async Task<Result<ChatListResponse>> ListAsync(ChatActor actor, string? queue,
        DateTimeOffset? beforeCreatedAt, Guid? beforeId, int limit, CancellationToken ct)
    {
        if (beforeCreatedAt.HasValue != beforeId.HasValue)
            return Invalid("Cursor hội thoại không hợp lệ.");
        if (actor.IsAdmin && !await admins.IsActiveAdminAsync(actor.UserId, ct))
            return Error.Forbidden("support.chat.forbidden", "Tài khoản Admin không hoạt động.");
        limit = Math.Clamp(limit, 1, 50);
        var query = db.ChatConversations.AsNoTracking()
            .Join(db.SupportTickets.AsNoTracking(), c => c.TicketId, t => t.Id,
                (c, t) => new { c, t });
        if (actor.IsAdmin)
        {
            query = queue?.ToLowerInvariant() switch
            {
                "new" => query.Where(x => x.t.Status == "NEW"),
                "mine" => query.Where(x => x.t.AssignedAdminId == actor.UserId && x.t.Status == "IN_PROGRESS"),
                "active" => query.Where(x => x.t.Status == "NEW" || x.t.Status == "IN_PROGRESS"),
                "closed" => query.Where(x => x.t.Status == "RESOLVED" || x.t.Status == "CLOSED"),
                null or "" => query,
                _ => query.Where(x => false)
            };
        }
        else query = query.Where(x => x.c.OwnerUserId == actor.UserId);
        if (beforeCreatedAt is { } before && beforeId is { } tie)
            query = query.Where(x => x.c.CreatedAt < before ||
                (x.c.CreatedAt == before && x.c.Id.CompareTo(tie) < 0));
        var rows = await query.OrderByDescending(x => x.c.CreatedAt).ThenByDescending(x => x.c.Id)
            .Take(limit + 1).Select(x => x.c).ToListAsync(ct);
        var items = new List<ChatConversationResponse>();
        foreach (var row in rows.Take(limit)) items.Add(await ToConversationAsync(row, actor, ct));
        var last = rows.Take(limit).LastOrDefault();
        return new ChatListResponse(items, rows.Count > limit, last?.CreatedAt, last?.Id);
    }

    public async Task<Result<ChatConversationResponse>> GetAsync(ChatActor actor, Guid id, CancellationToken ct)
    {
        var conversation = await VisibleAsync(actor, id, ct);
        return conversation is null ? Missing : await ToConversationAsync(conversation, actor, ct);
    }

    public async Task<Result<ChatPageResponse<ChatMessageResponse>>> MessagesAsync(ChatActor actor, Guid id,
        long? before, long? after, long? highWatermark, int limit, CancellationToken ct)
    {
        if (before is <= 0 || after is < 0 || highWatermark is < 0 ||
            (before.HasValue && after.HasValue)) return Invalid("Cursor không hợp lệ.");
        var conversation = await VisibleAsync(actor, id, ct);
        if (conversation is null) return Missing;
        limit = Math.Clamp(limit, 1, 100);
        var ceiling = Math.Min(highWatermark ?? conversation.LastSequence, conversation.LastSequence);
        var query = db.ChatMessages.AsNoTracking().Where(x =>
            x.ConversationId == id && x.Sequence <= ceiling);
        if (before is { } b) query = query.Where(x => x.Sequence < b);
        if (after is { } a) query = query.Where(x => x.Sequence > a);
        var rows = after.HasValue
            ? await query.OrderBy(x => x.Sequence).Take(limit + 1).ToListAsync(ct)
            : await query.OrderByDescending(x => x.Sequence).Take(limit + 1).ToListAsync(ct);
        var page = rows.Take(limit).OrderBy(x => x.Sequence).ToArray();
        return new ChatPageResponse<ChatMessageResponse>(
            page.Select(x => ToMessage(x, actor.UserId)).ToArray(), rows.Count > limit,
            page.Length == 0 ? null : page[0].Sequence,
            page.Length == 0 ? after : page[^1].Sequence, ceiling);
    }

    public async Task<Result<ChatActivityListResponse>> ActivitiesAsync(ChatActor actor,
        Guid id, DateTimeOffset? beforeCreatedAt, Guid? beforeId, int limit,
        CancellationToken ct)
    {
        if (beforeCreatedAt.HasValue != beforeId.HasValue)
            return Invalid("Cursor hoạt động không hợp lệ.");
        if (await VisibleAsync(actor, id, ct) is null) return Missing;
        limit = Math.Clamp(limit, 1, 100);
        var q = db.ChatActivityEvents.AsNoTracking().Where(x => x.ConversationId == id);
        if (beforeCreatedAt is { } before && beforeId is { } tie)
            q = q.Where(x => x.CreatedAt < before ||
                (x.CreatedAt == before && x.Id.CompareTo(tie) < 0));
        var rows = await q.OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id)
            .Take(limit + 1).ToListAsync(ct);
        var page = rows.Take(limit).Select(x => new ChatActivityResponse(x.Id, x.Action,
            x.FromStatus, x.ToStatus, actor.IsAdmin ? x.FromAdminId : null,
            actor.IsAdmin ? x.ToAdminId : null,
            actor.IsAdmin || x.Action == "STATUS" ? x.Reason : null, x.CreatedAt)).ToArray();
        return new ChatActivityListResponse(page, rows.Count > limit,
            page.Length == 0 ? null : page[^1].CreatedAt,
            page.Length == 0 ? null : page[^1].Id);
    }

    public async Task<Result<ChatMessageResponse>> SendAsync(ChatActor actor, Guid id, Guid key,
        string rawBody, CancellationToken ct)
    {
        if (!Enabled) return Disabled;
        if (key == Guid.Empty) return Invalid("Idempotency-Key phải là UUID khác rỗng.");
        var body = Normalize(rawBody);
        if (body.Length is < 1 or > 2000) return Invalid("Tin nhắn cần 1–2.000 ký tự.");
        var hash = Hash(body);
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var locked = await LockAsync(actor, id, ct);
        if (locked is null) return Missing;
        var (conversation, ticket) = locked.Value;
        var prior = await db.ChatMessages.AsNoTracking().SingleOrDefaultAsync(x =>
            x.ConversationId == id && x.SenderUserId == actor.UserId && x.IdempotencyKey == key, ct);
        if (prior is not null)
        {
            if (prior.PayloadHash != hash)
                return Conflict("idempotency_conflict", "Khóa đã dùng cho nội dung khác.");
            metrics?.Replayed("send");
            return ToMessage(prior, actor.UserId, true);
        }
        if (conversation.ClosedAt is not null || ticket.Status is "RESOLVED" or "CLOSED")
            return Conflict("closed", "Hội thoại đã kết thúc.");
        if (actor.IsAdmin && ticket.AssignedAdminId != actor.UserId)
            return Conflict("not_assigned", "Bạn chưa được phân công hội thoại này.");
        var now = DateTimeOffset.UtcNow;
        var message = ChatMessage.Create(id, conversation.AddMessage(now), actor.UserId,
            actor.Role, key, body, hash, now);
        db.ChatMessages.Add(message);
        if (actor.IsAdmin)
        {
            var notice = Notification.Create(conversation.OwnerUserId, "SUPPORT_CHAT",
                "Bạn có phản hồi mới từ CareSitter", "Bạn có phản hồi mới từ CareSitter",
                JsonSerializer.Serialize(new Dictionary<string, string>
                {
                    ["conversationId"] = id.ToString(), ["deepLink"] = "/settings/support/chat"
                }));
            if (notice.IsFailure) return notice.Error;
            notice.Value.LinkChatMessage(message.Id);
            db.Notifications.Add(notice.Value);
            if (configuration.GetValue<bool>("SupportChat:PushEnabled"))
            {
                var recipient = await recipients.GetAsync(conversation.OwnerUserId, ct);
                if (recipient.SupportChatPushEnabled && recipient.PushTokens.Length > 0)
                {
                    if (messaging is not { Enabled: true, NotificationsEnabled: true } ||
                        serializer is null || outbox is null)
                        throw new InvalidOperationException("SupportChat push requires the notification outbox.");
                    var eventId = message.Id;
                    var envelope = serializer.Create(new NotificationRequested(notice.Value.Id,
                            conversation.OwnerUserId, ["push"], "SUPPORT_CHAT"),
                        new EventMetadata(eventId, now, messaging.Producer,
                            conversation.OwnerUserId.ToString(),
                            System.Diagnostics.Activity.Current?.TraceId.ToString()));
                    db.Set<NotificationDelivery>().Add(new NotificationDelivery
                    {
                        EventId = eventId, NotificationId = notice.Value.Id, Channel = "push"
                    });
                    outbox.Add(envelope);
                }
            }
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        metrics?.MessageCommitted(actor.Role);
        await SignalAsync(SupportChatHub.ConversationGroup(id), "MessageCreated", new
        {
            eventId = message.Id, conversationId = id, messageId = message.Id,
            sequence = message.Sequence, createdAt = message.CreatedAt
        });
        await SignalAsync(SupportChatHub.OwnerGroup(conversation.OwnerUserId), "ConversationChanged", new
        {
            conversationId = id, ticketStatus = ticket.Status, assignedAdminId = ticket.AssignedAdminId,
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });
        await SignalAsync(SupportChatHub.AdminQueueGroup, "AdminQueueChanged", new
        {
            conversationId = id, changeType = "MESSAGE_CREATED",
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });
        return ToMessage(message, actor.UserId);
    }

    public async Task<Result<ChatConversationResponse>> ReadAsync(ChatActor actor, Guid id,
        long sequence, CancellationToken ct)
    {
        if (!Enabled) return Disabled;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var locked = await LockAsync(actor, id, ct);
        if (locked is null) return Missing;
        var (conversation, ticket) = locked.Value;
        // Queue triage may inspect a conversation, but only its assigned admin
        // can acknowledge messages on behalf of support staff.
        if (actor.IsAdmin && ticket.AssignedAdminId != actor.UserId)
            return Conflict("not_assigned", "Bạn chưa được phân công hội thoại này.");
        if (sequence < 0 || sequence > conversation.LastSequence)
            return Invalid("Vị trí đã đọc không hợp lệ.");
        var cursor = await db.ChatReadCursors.SingleOrDefaultAsync(x =>
            x.ConversationId == id && x.UserId == actor.UserId, ct);
        var advanced = cursor is null ? sequence > 0 : sequence > cursor.LastReadSequence;
        if (cursor is null && advanced)
        {
            cursor = new ChatReadCursor { ConversationId = id, UserId = actor.UserId,
                LastReadSequence = sequence, UpdatedAt = DateTimeOffset.UtcNow };
            db.ChatReadCursors.Add(cursor);
        }
        else if (cursor is not null && sequence > cursor.LastReadSequence)
        {
            cursor.LastReadSequence = sequence;
            cursor.UpdatedAt = DateTimeOffset.UtcNow;
        }
        if (advanced) conversation.MarkRead(sequence, actor.IsAdmin, DateTimeOffset.UtcNow);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        if (advanced)
        {
            await SignalAsync(SupportChatHub.OwnerGroup(actor.UserId), "ReadCursorChanged", new
            {
                conversationId = id, userId = actor.UserId, lastReadSequence = sequence
            });
            await SignalAsync(SupportChatHub.ConversationGroup(id), "ConversationChanged", new
            {
                conversationId = id, ticketStatus = ticket.Status,
                assignedAdminId = ticket.AssignedAdminId,
                ticketVersion = ticket.Version, conversationVersion = conversation.Version
            });
        }
        return await ToConversationAsync(conversation, actor, ct);
    }

    public Task<Result<ChatConversationResponse>> ClaimAsync(ChatActor actor, Guid id,
        long expectedVersion, CancellationToken ct) =>
        MutateAsync(actor, id, expectedVersion, "CLAIM", null, null, null, false, ct);

    public Task<Result<ChatConversationResponse>> TransferAsync(ChatActor actor, Guid id,
        Guid targetAdminId, bool takeover, long expectedVersion, string reason,
        CancellationToken ct) =>
        MutateAsync(actor, id, expectedVersion, takeover ? "TAKEOVER" : "TRANSFER",
            targetAdminId, null, reason, takeover, ct);

    public Task<Result<ChatConversationResponse>> StatusAsync(ChatActor actor, Guid id,
        string status, long expectedVersion, string reason, CancellationToken ct) =>
        MutateAsync(actor, id, expectedVersion, "STATUS", null,
            status?.Trim().ToUpperInvariant(), reason, false, ct);

    private async Task<Result<ChatConversationResponse>> MutateAsync(ChatActor actor, Guid id,
        long expectedVersion, string action, Guid? targetAdminId, string? targetStatus,
        string? reason, bool takeover, CancellationToken ct)
    {
        if (!Enabled) return Disabled;
        if (!actor.IsAdmin) return Error.Forbidden("support.chat.forbidden", "Chỉ Admin được xử lý.");
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var locked = await LockAsync(actor, id, ct);
        if (locked is null) return Missing;
        var (conversation, ticket) = locked.Value;
        if (ticket.Version != expectedVersion)
        {
            metrics?.VersionConflict();
            return Conflict("version_conflict", "Hội thoại đã thay đổi. Vui lòng tải lại.");
        }
        var oldStatus = ticket.Status;
        var oldAdmin = ticket.AssignedAdminId;
        var now = DateTimeOffset.UtcNow;
        Result operation;
        if (action == "CLAIM")
        {
            if (ticket.Status != "NEW" || ticket.AssignedAdminId is not null)
                return Conflict("not_claimable", "Hội thoại đã được nhận.");
            operation = ticket.AssignAdmin(actor.UserId);
        }
        else if (action is "TRANSFER" or "TAKEOVER")
        {
            if (ticket.Status != "IN_PROGRESS" || targetAdminId is null ||
                targetAdminId == Guid.Empty || string.IsNullOrWhiteSpace(reason) || reason.Length > 2000)
                return Invalid("Cần Admin đích và lý do chuyển hợp lệ.");
            if (!takeover && ticket.AssignedAdminId != actor.UserId)
                return Conflict("not_assigned", "Bạn không phụ trách hội thoại này.");
            if (takeover && ticket.AssignedAdminId == actor.UserId)
                return Conflict("not_assigned", "Bạn đã phụ trách hội thoại này.");
            if (targetAdminId == ticket.AssignedAdminId)
                return Conflict("not_assigned", "Admin đích đang phụ trách hội thoại này.");
            if (!await admins.IsActiveAdminAsync(targetAdminId.Value, ct))
                return Invalid("Tài khoản đích không phải Admin đang hoạt động.");
            operation = ticket.AssignAdmin(targetAdminId.Value);
        }
        else
        {
            if (targetStatus is null || targetStatus is not ("RESOLVED" or "CLOSED"))
                return Invalid("Trạng thái kết thúc không hợp lệ.");
            if (string.IsNullOrWhiteSpace(reason) || reason.Length > 2000)
                return Invalid("Cần lý do hoặc kết quả xử lý (tối đa 2.000 ký tự).");
            if (ticket.Status == "IN_PROGRESS" && ticket.AssignedAdminId != actor.UserId)
                return Conflict("not_assigned", "Bạn không phụ trách hội thoại này.");
            if (ticket.Status == "NEW" && targetStatus != "CLOSED")
                return Conflict("invalid_transition", "Ticket mới chỉ có thể đóng triage.");
            if (ticket.Status == "RESOLVED" && ticket.AssignedAdminId != actor.UserId)
                return Conflict("not_assigned", "Bạn không phụ trách hội thoại này.");
            operation = ticket.UpdateStatus(targetStatus);
        }
        if (operation.IsFailure) return operation.Error;
        ticket.AdvanceVersion();
        conversation.Change(now, ticket.Status is "RESOLVED" or "CLOSED");
        AddActivity(id, actor.UserId, action, oldStatus, ticket.Status,
            oldAdmin, ticket.AssignedAdminId, reason, now);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        await SignalAsync(SupportChatHub.ConversationGroup(id), "ConversationChanged", new
        {
            conversationId = id, ticketStatus = ticket.Status, assignedAdminId = ticket.AssignedAdminId,
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });
        await SignalAsync(SupportChatHub.OwnerGroup(conversation.OwnerUserId), "ConversationChanged", new
        {
            conversationId = id, ticketStatus = ticket.Status, assignedAdminId = ticket.AssignedAdminId,
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });
        await SignalAsync(SupportChatHub.AdminQueueGroup, "AdminQueueChanged", new
        {
            conversationId = id, changeType = action,
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });
        return await ToConversationAsync(conversation, actor, ct);
    }

    private async Task<(ChatConversation Conversation, SupportTicket Ticket)?> LockAsync(
        ChatActor actor, Guid id, CancellationToken ct)
    {
        if (actor.IsAdmin && !await admins.IsActiveAdminAsync(actor.UserId, ct)) return null;
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
        if (conversation is null || (!actor.IsAdmin && conversation.OwnerUserId != actor.UserId)) return null;
        return (conversation, ticket);
    }

    private async Task<ChatConversation?> VisibleAsync(ChatActor actor, Guid id, CancellationToken ct)
    {
        if (actor.IsAdmin && !await admins.IsActiveAdminAsync(actor.UserId, ct)) return null;
        return await db.ChatConversations.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id &&
            (actor.IsAdmin || x.OwnerUserId == actor.UserId), ct);
    }

    private async Task<ChatConversationResponse> ToConversationAsync(ChatConversation conversation,
        ChatActor actor, CancellationToken ct)
    {
        var ticket = await db.SupportTickets.AsNoTracking().SingleAsync(x => x.Id == conversation.TicketId, ct);
        var ownRead = await db.ChatReadCursors.AsNoTracking().Where(x =>
            x.ConversationId == conversation.Id && x.UserId == actor.UserId)
            .Select(x => (long?)x.LastReadSequence).SingleOrDefaultAsync(ct) ?? 0;
        var unread = await db.ChatMessages.AsNoTracking().CountAsync(x =>
            x.ConversationId == conversation.Id && x.SenderUserId != actor.UserId &&
            x.Sequence > ownRead, ct);
        return new ChatConversationResponse(conversation.Id, ticket.Id,
            conversation.OwnerUserId, ticket.BookingId, ticket.Title, ticket.Status,
            ticket.AssignedAdminId, ticket.Version, conversation.Version,
            conversation.LastSequence, ownRead, conversation.StaffLastReadSequence,
            unread, conversation.CreatedAt, conversation.ClosedAt);
    }

    private void AddActivity(Guid conversationId, Guid actorId, string action,
        string? fromStatus, string? toStatus, Guid? fromAdmin, Guid? toAdmin,
        string? reason, DateTimeOffset now) => db.ChatActivityEvents.Add(new ChatActivityEvent
        {
            Id = Guid.NewGuid(), ConversationId = conversationId, ActorUserId = actorId,
            Action = action, FromStatus = fromStatus, ToStatus = toStatus,
            FromAdminId = fromAdmin, ToAdminId = toAdmin, Reason = reason, CreatedAt = now
        });

    private static ChatMessageResponse ToMessage(ChatMessage message, Guid actorId, bool replayed = false) =>
        new(message.Id, message.ConversationId, message.Sequence, message.SenderUserId,
            message.SenderRole, message.Body, message.CreatedAt,
            message.SenderUserId == actorId ? message.IdempotencyKey : null, replayed);
    private static string Normalize(string? body) => (body ?? string.Empty)
        .Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n').Trim();
    private static string Hash(string body) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(body))).ToLowerInvariant();
    private async Task SignalAsync(string group, string eventName, object payload)
    {
        try
        {
            await hub.Clients.Group(group).SendCoreAsync(eventName, [payload]);
        }
        catch (Exception ex)
        {
            metrics?.FanoutFailure(eventName);
            logger.LogWarning(ex, "Support chat realtime signal failed for {EventName}", eventName);
        }
    }
    private static Error Invalid(string message) => Error.Validation("support.chat.invalid_request", message);
    private static Error Conflict(string suffix, string message) =>
        Error.Conflict($"support.chat.{suffix}", message);
}
