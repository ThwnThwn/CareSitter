using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Backfill và đối soát hội thoại chat cho booking đã nhận ca từ trước khi bật tính năng.
///
/// Nguyên tắc:
/// - Không tạo giả lịch sử nhận ca/check-in; chỉ thêm một mục "chat được kích hoạt".
/// - Giữ nguyên thứ tự khóa booking row → conversation để không đua với luồng accept.
/// - Hạn nhắn sau ca dùng timestamp đáng tin đã có; thiếu mốc thì để trống (chỉ đọc),
///   tuyệt đối không cộng 24 giờ kể từ ngày backfill.
/// </summary>
internal sealed class BookingChatBackfillStore(
    BookingDbContext db, IPeopleLookupService people) : IBookingChatBackfillStore
{
    // Chỉ booking đã thực sự qua bước nhận ca mới nên có hội thoại.
    private static readonly string[] BackfillStatuses =
    [
        "CAREGIVER_ACCEPTED", "CAREGIVER_EN_ROUTE", "IN_PROGRESS",
        "CHECKOUT_PENDING_REVIEW", "COMPLETED", "CANCELLED", "DISPUTED",
        "CRISIS", "REFUNDED"
    ];

    public async Task<BookingChatBackfillResult> BackfillMissingConversationsAsync(
        int batchSize, CancellationToken ct = default)
    {
        var size = Math.Clamp(batchSize, 1, 200);
        // Chỉ lấy ID trước; mỗi booking được khóa và xử lý trong transaction riêng
        // để không giữ khóa dài và không chặn accept của booking khác.
        var candidates = await db.Database.SqlQuery<Guid>($"""
            SELECT b.id AS "Value"
            FROM booking.bookings b
            WHERE b.caregiver_id IS NOT NULL
              AND b.status = ANY ({BackfillStatuses})
              AND NOT EXISTS (
                  SELECT 1 FROM booking.booking_chat_conversations c WHERE c.booking_id = b.id)
            ORDER BY b.created_at, b.id
            LIMIT {size + 1}
            """).ToListAsync(ct);

        var hasMore = candidates.Count > size;
        var examined = 0;
        var created = 0;

        foreach (var bookingId in candidates.Take(size))
        {
            examined++;
            if (await BackfillOneAsync(bookingId, ct)) created++;
        }

        return new BookingChatBackfillResult(examined, created, 0, hasMore);
    }

    public Task<int> CountMissingConversationsAsync(CancellationToken ct = default) =>
        db.Database.SqlQuery<int>($"""
            SELECT count(*)::int AS "Value"
            FROM booking.bookings b
            WHERE b.caregiver_id IS NOT NULL
              AND b.status = ANY ({BackfillStatuses})
              AND NOT EXISTS (
                  SELECT 1 FROM booking.booking_chat_conversations c WHERE c.booking_id = b.id)
            """).SingleAsync(ct);

    private async Task<bool> BackfillOneAsync(Guid bookingId, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Cùng thứ tự khóa với BookingAcceptanceTransaction: booking row trước.
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null || booking.CaregiverId is not { } caregiverProfileId)
        {
            await tx.RollbackAsync(ct);
            return false;
        }

        // Một lần accept/backfill khác có thể đã tạo hội thoại trong lúc chờ khóa.
        if (await db.BookingChatConversations.AnyAsync(x => x.BookingId == bookingId, ct))
        {
            await tx.RollbackAsync(ct);
            return false;
        }

        var caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(
            caregiverProfileId, ct);
        if (caregiverUserId is null)
        {
            await tx.RollbackAsync(ct);
            return false;
        }

        var occurredAt = DateTimeOffset.UtcNow;
        var conversation = BookingChatConversation.Create(bookingId, occurredAt);
        var epoch = BookingChatEpoch.CreateFirst(conversation.Id, caregiverProfileId,
            caregiverUserId.Value, occurredAt);
        ApplyExistingDeadlines(conversation, booking, occurredAt);

        var message = BookingChatMessage.CreateSystem(conversation.Id, epoch.Id, 1,
            BookingChatSourceEventIds.CreateForBackfill(bookingId, booking.SyncVersion),
            "Chat đã được kích hoạt cho lịch này.", occurredAt);

        db.BookingChatConversations.Add(conversation);
        db.BookingChatEpochs.Add(epoch);
        db.BookingChatMessages.Add(message);
        db.BookingChatOutbox.AddRange(
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                message.Id, "SYSTEM_MESSAGE_CREATED", conversation.ChangeVersion, occurredAt),
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, caregiverUserId.Value,
                message.Id, "SYSTEM_MESSAGE_CREATED", conversation.ChangeVersion, occurredAt));

        try
        {
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return true;
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
            { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Unique index booking_id bảo vệ lần chạy đua; coi như đã có hội thoại.
            await tx.RollbackAsync(ct);
            return false;
        }
    }

    /// <summary>
    /// Chỉ dùng timestamp đã có trên booking. Không suy diễn mốc thời gian mới và
    /// không cộng thời hạn nhắn tính từ lúc backfill.
    /// </summary>
    private static void ApplyExistingDeadlines(
        BookingChatConversation conversation, Domain.Booking booking, DateTimeOffset now)
    {
        var graceStartedAt = booking.Status switch
        {
            BookingStatus.CheckoutPendingReview => booking.CheckoutPendingReviewAt,
            BookingStatus.Completed => booking.ActualEnd,
            _ => null
        };
        if (graceStartedAt is { } startedAt)
            conversation.SnapshotGraceWindow(startedAt, BookingChatLifecyclePolicy.DefaultPostShiftGrace);

        var closedAt = booking.Status switch
        {
            BookingStatus.Cancelled or BookingStatus.Refunded => booking.CancelledAt ?? booking.ActualEnd,
            _ => null
        };
        if (closedAt is { } closed)
            conversation.ScheduleRetention(closed, TimeSpan.FromDays(180));

        // Hội thoại backfill có ngay mốc thời gian nên UpdatedAt phải phản ánh lúc tạo,
        // không phải lúc booking cũ đóng.
        _ = now;
    }
}

