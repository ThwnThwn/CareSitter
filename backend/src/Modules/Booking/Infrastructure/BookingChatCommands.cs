using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

// Lock the booking before the conversation so writes see a consistent participant assignment.
internal sealed class BookingChatCommands(
    BookingDbContext db,
    ICurrentUser currentUser,
    BookingChatParticipantAccess participantAccess,
    IOptions<BookingChatOptions> options) : IBookingChatCommands
{
    private readonly BookingChatOptions _options = options.Value;

    public async Task<Result<BookingChatMessageResponse>> SendAsync(
        Guid bookingId, Guid idempotencyKey, BookingChatSendRequest request,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();
        if (!_options.Enabled) return BookingChatErrors.Disabled();
        if (idempotencyKey == Guid.Empty)
            return BookingChatErrors.InvalidRequest("Idempotency-Key phải là UUID hợp lệ.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();
        var epoch = await db.BookingChatEpochs.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_epochs WHERE conversation_id = {conversation.Id} AND ended_at IS NULL FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (epoch is null) return BookingChatErrors.NotReady();
        if (role == "CAREGIVER" && epoch.CaregiverUserId != userId)
            return BookingChatErrors.NotFound();

        var prepared = BookingChatMessageContent.Prepare(request, role, booking.Status);
        if (prepared.IsFailure) return prepared.Error;
        var payloadHash = BookingChatMessageContent.ComputePayloadHash(prepared.Value, request.ExpectedEpochId);
        var existing = await db.BookingChatMessages.SingleOrDefaultAsync(x =>
            x.ConversationId == conversation.Id && x.SenderUserId == userId &&
            x.IdempotencyKey == idempotencyKey, ct);
        if (existing is not null)
        {
            if (existing.PayloadHash != payloadHash)
                return BookingChatErrors.IdempotencyConflict();
            if (role == "CAREGIVER" && existing.EpochId != epoch.Id)
                return BookingChatErrors.NotFound();
            await tx.CommitAsync(ct);
            return BookingChatResponses.ToMessage(existing, userId);
        }

        if (request.ExpectedEpochId != epoch.Id)
            return BookingChatErrors.ScopeChanged();
        var otherUserId = role == "CUSTOMER" ? epoch.CaregiverUserId : booking.CustomerId;
        var blocked = await db.BookingChatUserBlocks.AsNoTracking().AnyAsync(x =>
            x.ConversationId == conversation.Id && x.UnblockedAt == null &&
            ((x.BlockerUserId == userId && x.BlockedUserId == otherUserId) ||
             (x.BlockerUserId == otherUserId && x.BlockedUserId == userId)), ct);
        if (blocked) return BookingChatErrors.Blocked();
        var now = DateTimeOffset.UtcNow;
        var lifecycle = BookingChatLifecyclePolicy.Evaluate(new(
            booking.Status, true, booking.CaregiverId is not null, now,
            conversation.WriteClosesAt, conversation.DisputeLockedAt,
            conversation.WriteBlockedAt, conversation.PurgedAt));
        if (!lifecycle.CanSend)
            return BookingChatErrors.ReadOnly(BookingChatResponses.ToApi(lifecycle.Reason));

        var next = conversation.AppendMessage(now);
        var message = BookingChatMessage.CreateUser(
            conversation.Id, epoch.Id, next.Sequence, userId, role,
            prepared.Value.Kind, prepared.Value.TemplateKey,
            prepared.Value.TemplateVersion, prepared.Value.TemplateParamsJson,
            prepared.Value.Body, idempotencyKey, payloadHash, now);
        db.BookingChatMessages.Add(message);
        db.BookingChatOutbox.AddRange(
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                message.Id, "USER_MESSAGE_CREATED", next.ChangeVersion, now),
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, epoch.CaregiverUserId,
                message.Id, "USER_MESSAGE_CREATED", next.ChangeVersion, now));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return BookingChatResponses.ToMessage(message, userId);
    }

    public async Task<Result<BookingChatReadResponse>> MarkReadAsync(
        Guid bookingId, BookingChatReadRequest request, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();
        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();

        var epoch = await db.BookingChatEpochs.SingleOrDefaultAsync(
            x => x.Id == request.EpochId && x.ConversationId == conversation.Id, ct);
        if (epoch is null) return BookingChatErrors.ScopeChanged();
        if (role == "CAREGIVER" &&
            (epoch.EndedAt is not null || epoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();
        var message = await db.BookingChatMessages.AsNoTracking().SingleOrDefaultAsync(
            x => x.Id == request.LastReadMessageId && x.ConversationId == conversation.Id &&
                x.EpochId == epoch.Id, ct);
        if (message is null)
            return BookingChatErrors.InvalidRequest("Tin nhắn đánh dấu đã đọc không thuộc phạm vi hiện tại.");

        var now = DateTimeOffset.UtcNow;
        var read = await db.BookingChatReadCursors.SingleOrDefaultAsync(x =>
            x.ConversationId == conversation.Id && x.EpochId == epoch.Id && x.UserId == userId, ct);
        var changed = false;
        if (read is null)
        {
            read = BookingChatReadCursor.Create(conversation.Id, epoch.Id, userId,
                message.Sequence, now);
            db.BookingChatReadCursors.Add(read);
            changed = true;
        }
        else
        {
            changed = read.Advance(message.Sequence, now);
        }

        if (changed)
        {
            var version = conversation.AdvanceChangeVersion(now);
            db.BookingChatOutbox.AddRange(
                BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                    null, "READ_CHANGED", version, now),
                BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, epoch.CaregiverUserId,
                    null, "READ_CHANGED", version, now));
            await db.SaveChangesAsync(ct);
        }
        await tx.CommitAsync(ct);
        return new BookingChatReadResponse(epoch.Id, read.LastReadSequence,
            conversation.ChangeVersion, changed);
    }

    public async Task<Result<BookingChatReportResponse>> ReportMessageAsync(
        Guid bookingId, Guid messageId, BookingChatReportRequest request,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();
        var reason = request.Reason?.Trim();
        if (messageId == Guid.Empty || string.IsNullOrWhiteSpace(reason) || reason.Length > 500)
            return BookingChatErrors.InvalidRequest("Lý do báo cáo phải từ 1 đến 500 ký tự.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();
        var reportLockKey = $"booking-chat-report:{messageId}:{userId}";
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({reportLockKey}, 0))", ct);
        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();
        var currentEpoch = await db.BookingChatEpochs.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (role == "CAREGIVER" &&
            (currentEpoch is null || currentEpoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();

        var messageQuery = db.BookingChatMessages.Where(x =>
            x.Id == messageId && x.ConversationId == conversation.Id && x.SenderUserId != null);
        if (role == "CAREGIVER")
            messageQuery = messageQuery.Where(x => x.EpochId == currentEpoch!.Id);
        var message = await messageQuery.SingleOrDefaultAsync(ct);
        if (message is null)
            return BookingChatErrors.InvalidRequest("Tin nhắn không thuộc phạm vi bạn có thể báo cáo.");
        if (message.SenderUserId == userId)
            return BookingChatErrors.InvalidRequest("Chỉ có thể báo cáo tin nhắn của người còn lại.");
        var existing = await db.BookingChatReports.SingleOrDefaultAsync(x =>
            x.MessageId == message.Id && x.ReporterUserId == userId, ct);
        if (existing is not null)
        {
            await tx.CommitAsync(ct);
            return new BookingChatReportResponse(
                existing.Id, existing.Status, existing.SupportTicketId);
        }

        var now = DateTimeOffset.UtcNow;
        var report = BookingChatReport.Create(message.Id, userId, reason, now);
        conversation.PlaceLegalHold("Báo cáo tin nhắn đang chờ xử lý", now);
        db.BookingChatReports.Add(report);
        db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(conversation.Id, userId,
            "MESSAGE_REPORTED", reason, now));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new BookingChatReportResponse(report.Id, report.Status, report.SupportTicketId);
    }

    public async Task<Result<BookingChatBlockResponse>> SetBlockAsync(
        Guid bookingId, BookingChatBlockRequest request, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();
        var epoch = await db.BookingChatEpochs.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_epochs WHERE conversation_id = {conversation.Id} AND ended_at IS NULL FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (epoch is null) return BookingChatErrors.NotReady();
        if (role == "CAREGIVER" && epoch.CaregiverUserId != userId)
            return BookingChatErrors.NotFound();

        var otherUserId = role == "CUSTOMER" ? epoch.CaregiverUserId : booking.CustomerId;
        var block = await db.BookingChatUserBlocks.SingleOrDefaultAsync(x =>
            x.ConversationId == conversation.Id && x.BlockerUserId == userId &&
            x.BlockedUserId == otherUserId, ct);
        var now = DateTimeOffset.UtcNow;
        bool changed;
        if (request.Blocked)
        {
            if (block is null)
            {
                block = BookingChatUserBlock.Create(
                    conversation.Id, userId, otherUserId, now);
                db.BookingChatUserBlocks.Add(block);
                changed = true;
            }
            else
            {
                changed = block.Block(now);
            }
        }
        else
        {
            changed = block?.Unblock(now) == true;
        }

        if (changed)
        {
            var version = conversation.AdvanceChangeVersion(now);
            db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(
                conversation.Id, userId,
                request.Blocked ? "USER_BLOCKED" : "USER_UNBLOCKED", null, now));
            db.BookingChatOutbox.AddRange(
                BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                    null, "USER_BLOCK_CHANGED", version, now),
                BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, epoch.CaregiverUserId,
                    null, "USER_BLOCK_CHANGED", version, now));
            await db.SaveChangesAsync(ct);
        }

        await tx.CommitAsync(ct);
        var isBlockedByMe = request.Blocked && block is { UnblockedAt: null };
        return new BookingChatBlockResponse(
            isBlockedByMe,
            changed,
            isBlockedByMe ? block!.BlockedAt : null);
    }
}
