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
