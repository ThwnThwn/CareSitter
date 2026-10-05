using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.Catalog.Application.Commands.UpdateAddress;

internal sealed class UpdateAddressCommandHandler(
    IAddressRepository repository,
    ICurrentUser currentUser,
    IPlaceAutocompleteService places,
    IClock clock) : IRequestHandler<UpdateAddressCommand, Result<AddressResponse>>
{
    public async Task<Result<AddressResponse>> Handle(UpdateAddressCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return CatalogErrors.Unauthenticated();
        var entity = await repository.GetOwnedAsync(request.AddressId, userId, ct);
        if (entity is null) return CatalogErrors.AddressNotFound();
        VerifiedPlaceDetails? verified;
        try
        {
            verified = await ResolvePlaceAsync(request.PlaceId, request.SessionToken, ct);
        }
        catch (InvalidOperationException ex)
        {
            return CatalogErrors.PlaceServiceUnavailable(ex.Message);
        }

        if (verified is null)
            return CatalogErrors.VerifiedPlaceRequired();

        var point = CreatePoint(verified.Latitude, verified.Longitude);
        if (point is null) return CatalogErrors.InvalidCoordinates();
        var result = entity.Update(verified.FormattedAddress, point, request.Label,
            verified.Ward, verified.District, verified.City, verified.Country,
            verified.PlaceId, "GEOAPIFY", clock.UtcNow, request.Note);
        if (result.IsFailure) return result.Error;
        await repository.SaveChangesAsync(ct);
        return CatalogResponseMapper.ToResponse(entity);
    }

    private static Point? CreatePoint(double latitude, double longitude)
    {
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180) return null;
        return new Point(longitude, latitude) { SRID = 4326 };
    }

    private async Task<VerifiedPlaceDetails?> ResolvePlaceAsync(
        string? placeId, string? sessionToken, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(placeId)) return null;
        try
        {
            return await places.GetDetailsAsync(placeId, sessionToken, ct);
        }
        catch (InvalidOperationException)
        {
            throw;
        }
    }
}
