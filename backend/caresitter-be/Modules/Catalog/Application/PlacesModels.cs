namespace CareSitter.Modules.Catalog.Application;

public sealed record PlaceSuggestion(
    string PlaceId,
    string Description,
    string MainText,
    string SecondaryText);

public sealed record VerifiedPlaceDetails(
    string PlaceId,
    string FormattedAddress,
    double Latitude,
    double Longitude,
    string? Ward,
    string? District,
    string? City,
    string Country);

public interface IPlaceAutocompleteService
{
    Task<IReadOnlyList<PlaceSuggestion>> AutocompleteAsync(
        string input,
        string? sessionToken,
        CancellationToken ct = default);

    Task<VerifiedPlaceDetails?> GetDetailsAsync(
        string placeId,
        string? sessionToken,
        CancellationToken ct = default);
}
