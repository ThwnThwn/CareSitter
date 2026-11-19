using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal static class PushDeliveryProgress
{
    public static async Task<bool> RecordAsync(SupportDbContext db, Guid eventId, Guid token, string[] keys, CancellationToken ct)
    {
        if (keys.Length is 0 or > 500 || keys.Any(k => k is not { Length: 64 } || !k.All(char.IsAsciiHexDigit)))
            return false;
        // Fence stale workers, deduplicate repeated receipts and renew the lease for the next batch.
        return await db.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE support.notification_deliveries SET completed_push_targets =
                ARRAY(SELECT DISTINCT unnest(completed_push_targets || {keys}::text[])),
                lease_until = now() + interval '45 seconds'
            WHERE event_id = {eventId} AND channel = 'push' AND claim_token = {token}
            """, ct) == 1;
    }
}
