using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.Infrastructure;

public sealed class LiveLocationCleanupJob
{
    private readonly ILiveLocationStore _store;
    internal LiveLocationCleanupJob(ILiveLocationStore store) => _store = store;

    public async Task RunAsync(CancellationToken ct)
    {
        // Bound each execution; SKIP LOCKED also makes overlapping runs safe.
        for (var batch = 0; batch < 20; batch++)
            if (await _store.DeleteExpiredBatchAsync(ct) < 500) break;
    }
}
