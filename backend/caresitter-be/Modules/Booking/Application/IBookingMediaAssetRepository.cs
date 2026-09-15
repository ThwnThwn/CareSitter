using CareSitter.Modules.Catalog.Domain;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingMediaAssetRepository
{
    Task AddAndSaveAsync(MediaAsset mediaAsset, CancellationToken ct);
}
