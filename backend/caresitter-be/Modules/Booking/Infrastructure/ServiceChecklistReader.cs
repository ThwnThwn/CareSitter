using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class ServiceChecklistReader(BookingDbContext db) : IServiceChecklistReader
{
    public async Task<IReadOnlyList<PublicServiceChecklistItem>> ListActiveAsync(
        Guid serviceTypeId, CancellationToken ct = default) =>
        await db.PackageTaskTemplates.AsNoTracking()
            .Where(item => item.ServiceTypeId == serviceTypeId && item.IsActive)
            .OrderBy(item => item.SortOrder)
            .ThenBy(item => item.Name)
            .Select(item => new PublicServiceChecklistItem(
                item.Id,
                item.ServiceTypeId,
                item.Name,
                item.Description,
                item.IsRequired,
                item.RequiresPhoto,
                item.SortOrder))
            .ToArrayAsync(ct);
}
