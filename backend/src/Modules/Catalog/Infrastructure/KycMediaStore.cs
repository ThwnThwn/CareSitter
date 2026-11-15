using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class KycMediaStore(CatalogDbContext db) : IKycMediaStore
{
    public async Task AddAsync(KycMediaAsset asset, CancellationToken ct)
    {
        if (!KycMediaPolicy.IsSecure(asset)) throw new ArgumentException("Only authenticated KYC media may be stored.");
        db.MediaAssets.Add(MediaAsset.CreateSecureKyc(asset.Id, asset.OwnerUserId,
            asset.CloudName, asset.ObjectKey, asset.Format, asset.DocumentType, asset.SizeBytes));
        await db.SaveChangesAsync(ct);
    }

    public async Task<KycMediaAsset?> FindAsync(Guid id, CancellationToken ct)
    {
        var asset = await db.MediaAssets.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == id && x.IsSensitive && x.StorageProvider == "CLOUDINARY" &&
            x.BookingId == null && x.OwnerUserId != null && x.DeliveryType == "authenticated" &&
            x.Url == null && x.FileFormat != null && x.DocumentType != null, ct);
        return asset is null ? null : new KycMediaAsset(asset.Id, asset.OwnerUserId!.Value,
            asset.Bucket, asset.ObjectKey, asset.FileFormat!, asset.DocumentType!, asset.SizeBytes ?? 0,
            asset.DeliveryType!);
    }
}
