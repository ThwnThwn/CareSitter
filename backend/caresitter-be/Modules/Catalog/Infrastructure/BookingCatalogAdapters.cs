using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class BookingMediaStore(CatalogDbContext db) : IBookingMediaStore
{
    public async Task<Result<Guid>> AddPhotoAsync(
        Guid ownerUserId, Guid bookingId, string url, string mimeType,
        long sizeBytes, CancellationToken ct = default)
    {
        var asset = MediaAsset.Create(
            "CLOUDINARY", "caresitter", url, "PHOTO",
            ownerUserId: ownerUserId, bookingId: bookingId, url: url,
            mimeType: mimeType, sizeBytes: sizeBytes);
        if (asset.IsFailure) return asset.Error;

        db.MediaAssets.Add(asset.Value);
        await db.SaveChangesAsync(ct);
        return asset.Value.Id;
    }

    public async Task<IReadOnlyDictionary<Guid, string>> GetUrlsAsync(
        IReadOnlyCollection<Guid> mediaIds, CancellationToken ct = default) =>
        await db.MediaAssets.AsNoTracking()
            .Where(x => mediaIds.Contains(x.Id) && x.Url != null)
            .ToDictionaryAsync(x => x.Id, x => x.Url!, ct);
}

internal sealed class ServiceChecklistCatalog(CatalogDbContext db) : IServiceChecklistCatalog
{
    public Task<bool> ExistsAsync(Guid serviceTypeId, CancellationToken ct = default) =>
        db.ServiceTypes.AsNoTracking().AnyAsync(x => x.Id == serviceTypeId, ct);

    public async Task<ServiceChecklistPolicyChange?> SetPolicyAsync(
        Guid serviceTypeId, bool allowAdHocTasks, CancellationToken ct = default)
    {
        var service = await db.ServiceTypes.SingleOrDefaultAsync(
            x => x.Id == serviceTypeId, ct);
        if (service is null) return null;

        var previous = service.AllowAdHocTasks;
        service.SetAllowAdHocTasks(allowAdHocTasks);
        await db.SaveChangesAsync(ct);
        return new ServiceChecklistPolicyChange(service.Id, previous, service.AllowAdHocTasks);
    }
}
