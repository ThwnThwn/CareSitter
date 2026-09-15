using CareSitter.Modules.Catalog.Domain;

namespace CareSitter.Modules.Catalog.Application;

internal static class CatalogResponseMapper
{
    public static AddressResponse ToResponse(Address address) => new(address.Id,
        address.FullAddress, address.Location.Y, address.Location.X, address.Label,
        address.Ward, address.District, address.City, address.Country, address.PlaceId,
        address.Provider, address.VerifiedAt, address.IsVerified, address.Note);
}
