using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.Catalog.Application.Commands.CreateAddress;

internal sealed class CreateAddressCommandHandler(
    IAddressRepository repository,
    ICurrentUser currentUser,
    IPlaceAutocompleteService places,
    IClock clock) : IRequestHandler<CreateAddressCommand, Result<AddressResponse>>
{
    public async Task<Result<AddressResponse>> Handle(CreateAddressCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return CatalogErrors.Unauthenticated();
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
        var created = Address.Create(verified.FormattedAddress, point, userId, request.Label,
            verified.Ward, verified.District, verified.City, verified.Country, verified.PlaceId,
            "GEOAPIFY", clock.UtcNow, request.Note);
        if (created.IsFailure) return created.Error;
        repository.Add(created.Value);
        await repository.SaveChangesAsync(ct);
        return CatalogResponseMapper.ToResponse(created.Value);
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
