namespace CareSitter.Modules.Catalog.Application;

public sealed record AddressResponse(Guid Id, string FullAddress, double Latitude,
    double Longitude, string? Label, string? Ward, string? District, string? City,
    string Country, string? PlaceId, string? Provider, DateTimeOffset? VerifiedAt,
    bool IsVerified, string? Note);

public sealed record DefaultAddressResponse(Guid DefaultAddressId, bool Validated);
