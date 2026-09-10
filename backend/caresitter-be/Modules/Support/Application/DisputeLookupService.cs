using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Application;

internal sealed class DisputeLookupService(SupportDbContext db) : IDisputeLookupService
{
    public Task<bool> HasOpenDisputeAsync(Guid bookingId, CancellationToken ct = default) =>
        db.Disputes.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId &&
            x.Status != "RESOLVED" &&
            x.Status != "CANCELLED", ct);
}
