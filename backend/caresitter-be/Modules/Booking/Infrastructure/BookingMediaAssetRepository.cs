using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingMediaAssetRepository(CatalogDbContext db) : IBookingMediaAssetRepository
{
    public async Task AddAndSaveAsync(MediaAsset mediaAsset, CancellationToken ct)
    {
        db.MediaAssets.Add(mediaAsset);
        await db.SaveChangesAsync(ct);
    }
}
