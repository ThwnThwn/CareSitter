using CareSitter.Infrastructure.Hubs;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Đẩy signal chat đã commit ra realtime. Event không mang body, không mang cursor
/// và không cấp quyền: client phải tải lại metadata/delta qua REST bằng phiên của mình.
/// Trước khi gửi, dispatcher kiểm lại conversation/epoch còn hợp lệ để sự kiện cũ
/// không chuyển sang caregiver mới sau khi lần phân công đã đổi.
/// </summary>
internal sealed class BookingChatDispatcher(
    BookingDbContext db,
    IHubContext<CareTrackingHub> hub,
    IUserNotificationService notifications,
    IOptions<BookingChatOptions> options,
    BookingChatMetrics metrics,
    ILogger<BookingChatDispatcher> logger) : IBookingChatDispatcher
{
    private readonly BookingChatOptions _options = options.Value;

    public async Task<int> DispatchPendingAsync(int batchSize, CancellationToken ct = default)
    {
        if (!_options.Enabled) return 0;

        var size = Math.Clamp(batchSize, 1, 200);
        var now = DateTimeOffset.UtcNow;
        var leaseUntil = now.AddSeconds(Math.Max(5, _options.DispatcherLeaseSeconds));
        var claimed = await ClaimAsync(size, now, leaseUntil, ct);
        var dispatched = 0;

        foreach (var signal in claimed)
        {
            try
            {
                if (await DispatchAsync(signal, ct))
                {
                    dispatched++;
                    metrics.Dispatched(signal.Kind);
                }
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                // Lỗi tạm thời: giữ nguyên row để thử lại, không mất signal.
                metrics.Failed();
                await MarkFailedAsync(signal, exception, ct);
            }
        }

        await ObserveBacklogAsync(now, ct);
        return dispatched;
    }

    /// <summary>Đo backlog và tuổi signal cũ nhất để cảnh báo vận hành.</summary>
    private async Task ObserveBacklogAsync(DateTimeOffset now, CancellationToken ct)
    {
        var pending = db.BookingChatOutbox.AsNoTracking()
            .Where(x => x.Status == "PENDING" || x.Status == "FAILED");
        var count = await pending.LongCountAsync(ct);
        var oldest = await pending.MinAsync(x => (DateTimeOffset?)x.CreatedAt, ct);
        metrics.ObserveBacklog(count, oldest is { } createdAt ? now - createdAt : null);
    }

    private async Task<IReadOnlyList<BookingChatOutboxEvent>> ClaimAsync(
        int batchSize, DateTimeOffset now, DateTimeOffset leaseUntil, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Bao gồm PROCESSING có lease đã hết hạn: nếu API dừng đột ngột sau khi claim
        // mà chưa gửi xong, lượt quét sau phải nhận lại signal thay vì bỏ kẹt row.
        // Đây là gửi "ít nhất một lần"; client gộp theo eventId/sequence nên không trùng.
        var claimed = await db.BookingChatOutbox.FromSqlInterpolated($$"""
            SELECT *
            FROM booking.booking_chat_outbox
            WHERE (status IN ('PENDING', 'FAILED') OR
                   (status = 'PROCESSING' AND lease_until IS NOT NULL AND lease_until <= {{now}}))
              AND available_at <= {{now}}
              AND (lease_until IS NULL OR lease_until <= {{now}})
            ORDER BY created_at, event_id
            LIMIT {{batchSize}}
            FOR UPDATE SKIP LOCKED
            """).AsNoTracking().ToListAsync(ct);

        foreach (var signal in claimed)
        {
            signal.Claim(now, leaseUntil);
            db.BookingChatOutbox.Update(signal);
        }

        if (claimed.Count > 0)
            await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        foreach (var signal in claimed)
            db.Entry(signal).State = EntityState.Detached;
        return claimed;
    }

    /// <summary>Trả về true khi signal đã xử lý xong (gửi được hoặc bỏ có chủ đích).</summary>
    private async Task<bool> DispatchAsync(BookingChatOutboxEvent signal, CancellationToken ct)
    {
        var context = await db.BookingChatConversations.AsNoTracking()
            .Where(x => x.Id == signal.ConversationId)
            .Select(x => new { x.BookingId, x.PurgedAt })
            .SingleOrDefaultAsync(ct);
        if (context is null)
        {
            await MarkDroppedAsync(signal, "conversation_missing", ct);
            return false;
        }
        if (context.PurgedAt is not null)
        {
            await MarkDroppedAsync(signal, "conversation_purged", ct);
            return false;
        }

        var epoch = await db.BookingChatEpochs.AsNoTracking()
            .Where(x => x.Id == signal.EpochId)
            .Select(x => new
            {
                x.ConversationId,
                x.CaregiverProfileId,
                x.CaregiverUserId,
                x.EndedAt
            })
            .SingleOrDefaultAsync(ct);
        if (epoch is null)
        {
            await MarkDroppedAsync(signal, "epoch_missing", ct);
            return false;
        }

        var booking = await db.Bookings.AsNoTracking()
            .Where(x => x.Id == context.BookingId)
            .Select(x => new { x.CustomerId, x.CaregiverId })
            .SingleOrDefaultAsync(ct);
        if (booking is null)
        {
            await MarkDroppedAsync(signal, "booking_missing", ct);
            return false;
        }

        var isCustomer = signal.RecipientUserId == booking.CustomerId;
        var group = isCustomer
            ? CareTrackingHub.CustomerGroup(signal.RecipientUserId)
            : CareTrackingHub.CaregiverGroup(signal.RecipientUserId);

        if (!isCustomer)
        {
            // Caregiver cũ mất quyền ngay khi epoch đóng hoặc booking đổi người.
            // Bỏ signal thay vì chuyển nội dung của lần phân công cũ sang người mới.
            var stillAssigned = epoch.EndedAt is null &&
                epoch.ConversationId == signal.ConversationId &&
                booking.CaregiverId is not null &&
                booking.CaregiverId == epoch.CaregiverProfileId &&
                epoch.CaregiverUserId == signal.RecipientUserId;
            if (!stillAssigned)
            {
                await MarkDroppedAsync(signal, "epoch_not_current", ct);
                return false;
            }
        }

        UserNotificationMessage? chatNotification = null;
        if (signal.Kind == "USER_MESSAGE_CREATED" &&
            signal.MessageId is { } messageId)
        {
            var senderUserId = await db.BookingChatMessages.AsNoTracking()
                .Where(x => x.Id == messageId)
                .Select(x => x.SenderUserId)
                .SingleOrDefaultAsync(ct);
            if (senderUserId is { } sender && sender != signal.RecipientUserId)
            {
                var deepLink = isCustomer
                    ? $"/bookings/{context.BookingId}/chat"
                    : $"/shifts/{context.BookingId}/chat";
                chatNotification = new UserNotificationMessage(
                    signal.RecipientUserId,
                    "BOOKING_CHAT",
                    "Tin nhắn mới về lịch chăm sóc",
                    "Bạn có tin nhắn mới. Mở ứng dụng để xem.",
                    new Dictionary<string, string>
                    {
                        ["bookingId"] = context.BookingId.ToString(),
                        ["conversationId"] = signal.ConversationId.ToString(),
                        ["messageId"] = messageId.ToString(),
                        ["deepLink"] = deepLink
                    },
                    signal.EventId,
                    DateTimeOffset.UtcNow,
                    SendPush: _options.PushEnabled);
            }
        }

        // Khi push bị tắt, vẫn ghi inbox trước khi phát realtime để client tải lại
        // và thấy notification ngay khi nhận BookingChatChanged.
        if (chatNotification is { SendPush: false })
            await notifications.NotifyAsync(chatNotification, ct);

        await hub.Clients.Group(group).SendAsync("BookingChatChanged",
            new BookingChatChangedEvent(
                context.BookingId,
                signal.ConversationId,
                signal.ChangeVersion,
                signal.EventId,
                signal.Kind,
                DateTimeOffset.UtcNow), ct);

        // Re-use the per-recipient outbox event as the notification identity. This
        // makes retries at-least-once while the notification service stays deduplicated.
        if (chatNotification is { SendPush: true })
            await notifications.NotifyAsync(chatNotification, ct);

        await MarkSentAsync(signal, ct);
        return true;
    }

    private async Task MarkSentAsync(BookingChatOutboxEvent signal, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        signal.MarkSent(now);
        db.BookingChatOutbox.Update(signal);
        await db.SaveChangesAsync(ct);
        db.Entry(signal).State = EntityState.Detached;
    }

    private async Task MarkDroppedAsync(
        BookingChatOutboxEvent signal, string reason, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        // Không gửi được vì lý do nghiệp vụ vĩnh viễn: đóng row kèm lý do để đối soát,
        // tuyệt đối không xóa row và không chuyển tiếp cho người không còn quyền.
        signal.MarkDropped(reason, now);
        db.BookingChatOutbox.Update(signal);
        await db.SaveChangesAsync(ct);
        db.Entry(signal).State = EntityState.Detached;
        metrics.Dropped(reason);
        logger.LogInformation(
            "Dropped booking chat signal {OutboxEventId} for conversation {ConversationId}: {Reason}.",
            signal.EventId, signal.ConversationId, reason);
    }

    private async Task MarkFailedAsync(
        BookingChatOutboxEvent signal, Exception exception, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var exhausted = signal.Attempts >= Math.Max(1, _options.DispatcherMaxAttempts);
        if (exhausted)
        {
            signal.MarkDeadLetter(exception.GetType().Name, now);
        }
        else
        {
            var delay = TimeSpan.FromSeconds(Math.Max(1, _options.DispatcherRetryDelaySeconds));
            signal.MarkFailed(exception.GetType().Name, now.Add(delay), now);
        }

        db.BookingChatOutbox.Update(signal);
        await db.SaveChangesAsync(ct);
        db.Entry(signal).State = EntityState.Detached;
        logger.LogWarning(exception,
            "Booking chat signal {OutboxEventId} for conversation {ConversationId} attempt {Attempt} failed.",
            signal.EventId, signal.ConversationId, signal.Attempts);
    }
}
