namespace CareSitter.Modules.Catalog.Application;

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
