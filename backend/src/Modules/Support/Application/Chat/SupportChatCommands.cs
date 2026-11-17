using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using static CareSitter.Modules.Support.Application.Chat.SupportChatErrors;

namespace CareSitter.Modules.Support.Application.Chat;

/// <summary>
/// Coordinates chat permissions, idempotency and ticket transitions through
/// persistence ports. Realtime signals are emitted after the transaction commits.
/// </summary>
internal sealed class SupportChatCommands(
    ISupportChatStore store, IBookingPartyAccess bookingAccess, IActiveAdminLookup admins,
    ISupportChatRealtimePublisher realtime, SupportChatMetrics? metrics = null)
    : ISupportChatCommands
{
    private bool Enabled => store.Enabled;

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

        await using var tx = await store.BeginAsync(ct);
        await store.LockOwnerAsync(actor.UserId, ct);
        var prior = await store.FindCreatedAsync(actor.UserId, key, ct);
        if (prior is not null)
        {
            if (prior.CreatePayloadHash != hash) return Conflict("idempotency_conflict", "Khóa đã dùng cho nội dung khác.");
            metrics?.Replayed("create");
            var first = await store.FirstMessageAsync(prior.Id, ct);
            var originalTicket = await store.TicketAsync(prior.TicketId, ct);
            var original = new ChatConversationResponse(prior.Id, originalTicket.Id,
                prior.OwnerUserId, originalTicket.BookingId, originalTicket.Title,
                "NEW", null, 1, 2, 1, 0, 0, 0, prior.CreatedAt, null);
            return new ChatCreateResponse(original,
                SupportChatMapping.ToMessage(first, actor.UserId, true), true);
        }
        var open = await store.OpenConversationAsync(actor.UserId, ct);
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
        store.AddTicket(ticket);
        store.AddConversation(conversation);
        store.AddMessage(message);
        AddActivity(conversation.Id, actor.UserId, "CREATED", null, "NEW", null, null, null, now);
        await store.SaveAsync(ct);
        await tx.CommitAsync(ct);
        metrics?.Created();
        metrics?.MessageCommitted(actor.Role);
        await realtime.ConversationCreatedAsync(conversation, ticket);
        return new ChatCreateResponse(await store.ResponseAsync(conversation, actor, ct),
            SupportChatMapping.ToMessage(message, actor.UserId), false);
    }

    public async Task<Result<ChatMessageResponse>> SendAsync(ChatActor actor, Guid id, Guid key,
        string rawBody, CancellationToken ct)
    {
        if (!Enabled) return Disabled;
        if (key == Guid.Empty) return Invalid("Idempotency-Key phải là UUID khác rỗng.");
        var body = Normalize(rawBody);
        if (body.Length is < 1 or > 2000) return Invalid("Tin nhắn cần 1–2.000 ký tự.");
        var hash = Hash(body);
        await using var tx = await store.BeginAsync(ct);
        var locked = await LockAsync(actor, id, ct);
        if (locked is null) return Missing;
        var (conversation, ticket) = locked.Value;
        var prior = await store.FindMessageAsync(id, actor.UserId, key, ct);
        if (prior is not null)
        {
            if (prior.PayloadHash != hash)
                return Conflict("idempotency_conflict", "Khóa đã dùng cho nội dung khác.");
            metrics?.Replayed("send");
            return SupportChatMapping.ToMessage(prior, actor.UserId, true);
        }
        if (conversation.ClosedAt is not null || ticket.Status is "RESOLVED" or "CLOSED")
            return Conflict("closed", "Hội thoại đã kết thúc.");
        if (actor.IsAdmin && ticket.AssignedAdminId != actor.UserId)
            return Conflict("not_assigned", "Bạn chưa được phân công hội thoại này.");
        var now = DateTimeOffset.UtcNow;
        var message = ChatMessage.Create(id, conversation.AddMessage(now), actor.UserId,
            actor.Role, key, body, hash, now);
        store.AddMessage(message);
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
            store.AddNotification(notice.Value);
            await store.EnqueuePushAsync(conversation.OwnerUserId, notice.Value.Id, message.Id, now, ct);
        }
        await store.SaveAsync(ct);
        await tx.CommitAsync(ct);
        metrics?.MessageCommitted(actor.Role);
        await realtime.MessageCreatedAsync(conversation, ticket, message);
        return SupportChatMapping.ToMessage(message, actor.UserId);
    }

    public async Task<Result<ChatConversationResponse>> ReadAsync(ChatActor actor, Guid id,
        long sequence, CancellationToken ct)
    {
        if (!Enabled) return Disabled;
        await using var tx = await store.BeginAsync(ct);
        var locked = await LockAsync(actor, id, ct);
        if (locked is null) return Missing;
        var (conversation, ticket) = locked.Value;
        // Queue triage may inspect a conversation, but only its assigned admin
        // can acknowledge messages on behalf of support staff.
        if (actor.IsAdmin && ticket.AssignedAdminId != actor.UserId)
            return Conflict("not_assigned", "Bạn chưa được phân công hội thoại này.");
        if (sequence < 0 || sequence > conversation.LastSequence)
            return Invalid("Vị trí đã đọc không hợp lệ.");
        var cursor = await store.ReadCursorAsync(id, actor.UserId, ct);
        var advanced = cursor is null ? sequence > 0 : sequence > cursor.LastReadSequence;
        if (cursor is null && advanced)
        {
            cursor = new ChatReadCursor { ConversationId = id, UserId = actor.UserId,
                LastReadSequence = sequence, UpdatedAt = DateTimeOffset.UtcNow };
            store.AddReadCursor(cursor);
        }
        else if (cursor is not null && sequence > cursor.LastReadSequence)
        {
            cursor.LastReadSequence = sequence;
            cursor.UpdatedAt = DateTimeOffset.UtcNow;
        }
        if (advanced) conversation.MarkRead(sequence, actor.IsAdmin, DateTimeOffset.UtcNow);
        await store.SaveAsync(ct);
        await tx.CommitAsync(ct);
        if (advanced)
            await realtime.ReadCursorChangedAsync(conversation, ticket, actor.UserId, sequence);
        return await store.ResponseAsync(conversation, actor, ct);
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
        await using var tx = await store.BeginAsync(ct);
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
        await store.SaveAsync(ct);
        await tx.CommitAsync(ct);
        await realtime.ConversationChangedAsync(conversation, ticket, action);
        return await store.ResponseAsync(conversation, actor, ct);
    }

    private async Task<(ChatConversation Conversation, SupportTicket Ticket)?> LockAsync(
        ChatActor actor, Guid id, CancellationToken ct)
    {
        if (actor.IsAdmin && !await admins.IsActiveAdminAsync(actor.UserId, ct)) return null;
        var locked = await store.LockAsync(id, ct);
        if (locked is null || (!actor.IsAdmin && locked.Value.Conversation.OwnerUserId != actor.UserId))
            return null;
        return locked;
    }

    private void AddActivity(Guid conversationId, Guid actorId, string action,
        string? fromStatus, string? toStatus, Guid? fromAdmin, Guid? toAdmin,
        string? reason, DateTimeOffset now) => store.AddActivity(new ChatActivityEvent
        {
            Id = Guid.NewGuid(), ConversationId = conversationId, ActorUserId = actorId,
            Action = action, FromStatus = fromStatus, ToStatus = toStatus,
            FromAdminId = fromAdmin, ToAdminId = toAdmin, Reason = reason, CreatedAt = now
        });

    private static string Normalize(string? body) => (body ?? string.Empty)
        .Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n').Trim();
    private static string Hash(string body) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(body))).ToLowerInvariant();
}
