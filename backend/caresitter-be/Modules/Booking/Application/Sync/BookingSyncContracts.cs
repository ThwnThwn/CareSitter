using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application.Sync;

public interface IBookingSyncService
{
    void WriteSyncEvent(Domain.Booking booking, string eventType);
    Task<long> GetCurrentCursorAsync(Guid customerId, CancellationToken ct = default);
    Task<BookingSyncDeltaResult> GetDeltaAsync(
        Guid customerId, long afterCursor, int batchSize = 100,
        CancellationToken ct = default);
}

public sealed record BookingSyncDeltaResult(
    IReadOnlyList<BookingSyncEvent> Events,
    long NextCursor,
    bool HasMore,
    bool ResetRequired)
{
    public static BookingSyncDeltaResult Reset() => new([], 0, false, true);
}
