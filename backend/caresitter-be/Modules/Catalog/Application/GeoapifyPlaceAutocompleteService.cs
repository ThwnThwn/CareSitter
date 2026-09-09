using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Catalog.Application;

/// <summary>
/// Triển khai IPlaceAutocompleteService dùng Geoapify Geocoding API (miễn phí, không cần billing).
/// Autocomplete  → /v1/geocode/autocomplete
/// GetDetails    → /v1/geocode/search?place_id=... (dùng place_id của Geoapify)
/// </summary>
internal sealed class GeoapifyPlaceAutocompleteService(
    HttpClient httpClient,
    IConfiguration configuration,
    IMemoryCache cache,
    ILogger<GeoapifyPlaceAutocompleteService> logger) : IPlaceAutocompleteService
{
    private const int DefaultTimeoutSeconds = 5;
    private const int MinInputLength = 3;
    private const int MaxResults = 5;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(15);

    public async Task<IReadOnlyList<PlaceSuggestion>> AutocompleteAsync(
        string input,
        string? sessionToken,
        CancellationToken ct = default)
    {
        input = input.Trim();
        if (input.Length < MinInputLength) return [];

        var apiKey = GetApiKey();
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(DefaultTimeoutSeconds));

        // Geoapify autocomplete: filter Vietnam, bias towards HCM
        var url = "/v1/geocode/autocomplete" +
                  $"?text={Uri.EscapeDataString(input)}" +
                  $"&apiKey={Uri.EscapeDataString(apiKey)}" +
                  "&filter=countrycode:vn" +
                  "&bias=proximity:106.6297,10.8231" + // Ho Chi Minh City
                  $"&limit={MaxResults}" +
                  "&lang=vi";

        GeoFeatureCollection? payload;
        try
        {
            payload = await httpClient.GetFromJsonAsync<GeoFeatureCollection>(url, cts.Token);
        }
        catch (OperationCanceledException ex) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning(ex, "Geoapify autocomplete timed out for input={Input}", input);
            throw new InvalidOperationException("Geoapify autocomplete timed out.", ex);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex, "Geoapify autocomplete failed for input={Input}", input);
            throw new InvalidOperationException("Geoapify autocomplete failed.", ex);
        }

        if (payload?.Features is null or { Length: 0 }) return [];

        return payload.Features
            .Where(f => f.Properties?.CountryCode is "vn" or "VN")
            .Select(f =>
            {
                var props = f.Properties!;
                var placeId = props.PlaceId ?? string.Empty;
                var formatted = props.Formatted ?? string.Empty;
                var mainText = props.AddressLine1 ?? formatted;
                var secondary = props.AddressLine2 ?? string.Empty;
                var details = ToVerifiedDetails(f, placeId);
                if (details is not null)
                {
                    cache.Set(CacheKey(placeId), details, CacheDuration);
                }

                return new PlaceSuggestion(placeId, formatted, mainText, secondary);
            })
            .Where(s => !string.IsNullOrWhiteSpace(s.PlaceId))
            .ToList();
    }

    public async Task<VerifiedPlaceDetails?> GetDetailsAsync(
        string placeId,
        string? sessionToken,
        CancellationToken ct = default)
    {
        placeId = placeId.Trim();
        if (string.IsNullOrWhiteSpace(placeId)) return null;

        if (cache.TryGetValue(CacheKey(placeId), out VerifiedPlaceDetails? cachedDetails))
            return cachedDetails;

        var apiKey = GetApiKey();
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(DefaultTimeoutSeconds));

        var url = "/v2/place-details" +
                  $"?id={Uri.EscapeDataString(placeId)}" +
                  $"&apiKey={Uri.EscapeDataString(apiKey)}" +
                  "&lang=vi";

        GeoFeatureCollection? payload;
        try
        {
            payload = await httpClient.GetFromJsonAsync<GeoFeatureCollection>(url, cts.Token);
        }
        catch (OperationCanceledException ex) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning(ex, "Geoapify GetDetails timed out for placeId={PlaceId}", placeId);
            throw new InvalidOperationException("Geoapify place details timed out.", ex);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex, "Geoapify GetDetails failed for placeId={PlaceId}", placeId);
            throw new InvalidOperationException("Geoapify place details failed.", ex);
        }

        var feature = payload?.Features?.FirstOrDefault();
        if (feature is null)
        {
            logger.LogInformation("Geoapify details returned no feature for placeId={PlaceId}", placeId);
            return null;
        }

        return ToVerifiedDetails(feature, placeId);
    }

    private static VerifiedPlaceDetails? ToVerifiedDetails(GeoFeature feature, string fallbackPlaceId)
    {
        var props = feature.Properties;
        if (props is null) return null;
        if (!string.Equals(props.CountryCode, "vn", StringComparison.OrdinalIgnoreCase))
            return null;

        var coords = feature.Geometry?.Coordinates;
        if (coords is not { Length: >= 2 }) return null;

        return new VerifiedPlaceDetails(
            PlaceId: props.PlaceId ?? fallbackPlaceId,
            FormattedAddress: props.Formatted ?? string.Empty,
            Latitude: coords[1],
            Longitude: coords[0],
            Ward: props.Suburb ?? props.Quarter,
            District: props.County ?? props.District,
            City: props.City ?? props.State,
            Country: "Vietnam");
    }

    private static string CacheKey(string placeId) => $"geoapify-place:{placeId}";

    private string GetApiKey()
    {
        var key = configuration["GEOAPIFY_API_KEY"] ?? configuration["Geoapify:ApiKey"];
        if (string.IsNullOrWhiteSpace(key))
            throw new InvalidOperationException("GEOAPIFY_API_KEY is not configured.");
        return key;
    }
}

// ── GeoJSON models ───────────────────────────────────────────────────────────

internal sealed record GeoFeatureCollection(
    [property: JsonPropertyName("features")] GeoFeature[]? Features);

internal sealed record GeoFeature(
    [property: JsonPropertyName("properties")] GeoProperties? Properties,
    [property: JsonPropertyName("geometry")] GeoGeometry? Geometry);

internal sealed record GeoGeometry(
    [property: JsonPropertyName("type")] string Type,
    [property: JsonPropertyName("coordinates")] double[]? Coordinates);

internal sealed record GeoProperties(
    [property: JsonPropertyName("place_id")] string? PlaceId,
    [property: JsonPropertyName("formatted")] string? Formatted,
    [property: JsonPropertyName("address_line1")] string? AddressLine1,
    [property: JsonPropertyName("address_line2")] string? AddressLine2,
    [property: JsonPropertyName("country_code")] string? CountryCode,
    [property: JsonPropertyName("suburb")] string? Suburb,
    [property: JsonPropertyName("quarter")] string? Quarter,
    [property: JsonPropertyName("county")] string? County,
    [property: JsonPropertyName("district")] string? District,
    [property: JsonPropertyName("city")] string? City,
    [property: JsonPropertyName("state")] string? State,
    [property: JsonPropertyName("housenumber")] string? HouseNumber,
    [property: JsonPropertyName("street")] string? Street);
