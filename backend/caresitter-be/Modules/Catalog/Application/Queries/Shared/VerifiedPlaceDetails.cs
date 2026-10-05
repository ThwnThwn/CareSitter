namespace CareSitter.Modules.Catalog.Application;

public sealed record VerifiedPlaceDetails(
    string PlaceId,
    string FormattedAddress,
    double Latitude,
    double Longitude,
    string? Ward,
    string? District,
    string? City,
    string Country);
