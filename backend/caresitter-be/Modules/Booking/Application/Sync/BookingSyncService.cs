using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Application.Sync;

/// <summary>
/// Service trung tâm cho realtime delta sync.
///
/// Hai trách nhiệm chính:
/// 1. WriteSyncEventAsync — ghi BookingSyncEvent trong cùng transaction với caller.
///    Caller phải SaveChangesAsync sau khi gọi — service KHÔNG tự gọi SaveChanges.
/// 2. GetDeltaAsync     — trả danh sách booking đã thay đổi kể từ cursor X.
/// </summary>
public sealed class BookingSyncService(BookingDbContext db)
{
    /// <summary>
    /// Tăng SyncVersion trên booking và tạo một BookingSyncEvent.
    /// Phải gọi trước SaveChangesAsync của caller để tất cả commit trong 1 transaction.
    /// </summary>
    public void WriteSyncEvent(Domain.Booking booking, string eventType)
    {
        // internal — chỉ gọi được trong assembly Booking
        booking.IncrementSyncVersion();

        db.BookingSyncEvents.Add(new BookingSyncEvent(
            booking.CustomerId,
            booking.Id,
            booking.SyncVersion,
            eventType));
    }

    /// <summary>
    /// Lấy cursor lớn nhất hiện tại của customer.
    /// Trả về 0 nếu chưa có event nào.
    /// Dùng sau initial load GET /bookings để client có mốc bắt đầu delta.
    /// </summary>
    public async Task<long> GetCurrentCursorAsync(Guid customerId, CancellationToken ct = default)
    {
        return await db.BookingSyncEvents
            .Where(e => e.CustomerId == customerId)
            .Select(e => (long?)e.Cursor)
            .MaxAsync(ct) ?? 0L;
    }

    /// <summary>
    /// Lấy delta: các booking_sync_events có cursor > <paramref name="afterCursor"/> thuộc customer.
    /// Trả về danh sách booking ID + version đã thay đổi, theo cursor ASC.
    /// Caller (controller) sẽ query booking entity để build full BookingResponse.
    ///
    /// Cursor âm hoặc lớn hơn cursor toàn cục hiện tại là không hợp lệ và cần full refresh.
    /// </summary>
    public async Task<BookingSyncDeltaResult> GetDeltaAsync(
        Guid customerId,
        long afterCursor,
        int batchSize = 100,
        CancellationToken ct = default)
    {
        const int maxBatchSize = 100;
        batchSize = Math.Clamp(batchSize, 1, maxBatchSize);

        // Cursor âm → invalid
        if (afterCursor < 0)
            return BookingSyncDeltaResult.Reset();

        // A cursor ahead of this customer's latest event can only come from
        // corrupt local state or a restored database; do not silently return an
        // empty delta in that case.
        var latestCursor = await db.BookingSyncEvents
            .Where(e => e.CustomerId == customerId)
            .Select(e => (long?)e.Cursor)
            .MaxAsync(ct) ?? 0L;
        if (afterCursor > latestCursor)
            return BookingSyncDeltaResult.Reset();

        // Lấy batchSize + 1 để phát hiện hasMore
        var events = await db.BookingSyncEvents
            .Where(e => e.CustomerId == customerId && e.Cursor > afterCursor)
            .OrderBy(e => e.Cursor)
            .Take(batchSize + 1)
            .ToListAsync(ct);

        bool hasMore = events.Count > batchSize;
        if (hasMore) events = events.Take(batchSize).ToList();

        long nextCursor = events.Count > 0
            ? events[^1].Cursor
            : afterCursor; // không có item mới → giữ cursor cũ

        return new BookingSyncDeltaResult(
            Events: events,
            NextCursor: nextCursor,
            HasMore: hasMore,
            ResetRequired: false);
    }
}

/// <summary>Kết quả từ GetDeltaAsync.</summary>
public sealed record BookingSyncDeltaResult(
    IReadOnlyList<BookingSyncEvent> Events,
    long NextCursor,
    bool HasMore,
    bool ResetRequired)
{
    /// <summary>Trả khi cursor không hợp lệ — client phải gọi full refresh.</summary>
    public static BookingSyncDeltaResult Reset() => new(
        Events: [],
        NextCursor: 0,
        HasMore: false,
        ResetRequired: true);
}
