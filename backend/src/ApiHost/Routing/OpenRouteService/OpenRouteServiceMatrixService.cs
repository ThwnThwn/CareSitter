using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using CareSitter.Contracts.Services.Routing;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Routing.OpenRouteService;

public sealed class OpenRouteServiceMatrixService(
    HttpClient httpClient,
    IConfiguration configuration,
    IOptions<RoutingOptions> options,
    RoutingMetrics metrics,
    ILogger<OpenRouteServiceMatrixService> logger) : IRouteMatrixService
{
    private const string Provider = "openrouteservice";
    private RoutingProviderOptions Config => options.Value.OpenRouteService;

    public async Task<IReadOnlyList<RouteMatrixItem>> CalculateAsync(
        IReadOnlyList<GeoPoint> origins,
        GeoPoint destination,
        CancellationToken ct = default)
    {
        ValidateRequest(origins, destination);
        var apiKey = configuration["ORS_API_KEY"] ?? configuration["OpenRouteService:ApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new RoutingProviderUnavailableException("OpenRouteService API key is not configured.");

        var locations = origins
            .Select(x => new[] { x.Longitude, x.Latitude })
            .Append([destination.Longitude, destination.Latitude])
            .ToArray();
        var destinationIndex = origins.Count;
        var request = new OpenRouteServiceMatrixRequest(
            Locations: locations,
            Sources: Enumerable.Range(0, origins.Count).ToArray(),
            Destinations: [destinationIndex],
            Metrics: ["distance", "duration"],
            Units: "m");

        metrics.Request(Provider, origins.Count);
        var stopwatch = Stopwatch.StartNew();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(Math.Max(1, Config.TimeoutSeconds)));

        try
        {
            using var response = await httpClient.PostAsJsonAsync(
                $"/v2/matrix/{Uri.EscapeDataString(Config.Profile)}",
                request,
                timeout.Token);

            if (response.StatusCode == HttpStatusCode.TooManyRequests)
            {
                metrics.RateLimited(Provider);
                throw new RoutingLimitExceededException("OpenRouteService quota exceeded.");
            }

            if ((int)response.StatusCode >= 500)
            {
                metrics.Failure(Provider, $"http_{(int)response.StatusCode}");
                throw new RoutingProviderUnavailableException($"OpenRouteService returned {(int)response.StatusCode}.");
            }

            if (response.StatusCode == HttpStatusCode.BadRequest ||
                response.StatusCode == HttpStatusCode.UnprocessableEntity)
            {
                metrics.Failure(Provider, $"http_{(int)response.StatusCode}");
                throw new RoutingInvalidLocationException("OpenRouteService rejected the routing coordinates.");
            }

            if (!response.IsSuccessStatusCode)
            {
                metrics.Failure(Provider, $"http_{(int)response.StatusCode}");
                throw new RoutingProviderUnavailableException($"OpenRouteService returned {(int)response.StatusCode}.");
            }

            var payload = await response.Content.ReadFromJsonAsync<OpenRouteServiceMatrixResponse>(cancellationToken: timeout.Token);
            var items = ToItems(payload, origins.Count);
            metrics.Success(Provider, items.Count(x => !x.IsRoutable), stopwatch.Elapsed.TotalMilliseconds);
            logger.LogInformation("OpenRouteService route matrix succeeded for {Origins} origins.", origins.Count);
            return items;
        }
        catch (OperationCanceledException ex) when (!ct.IsCancellationRequested)
        {
            metrics.Failure(Provider, "timeout");
            throw new RoutingProviderUnavailableException("OpenRouteService route matrix timed out.", ex);
        }
        catch (HttpRequestException ex)
        {
            metrics.Failure(Provider, "network");
            throw new RoutingProviderUnavailableException("OpenRouteService route matrix request failed.", ex);
        }
        catch (JsonException ex)
        {
            metrics.Failure(Provider, "invalid_response");
            throw new RoutingProviderUnavailableException("OpenRouteService route matrix response was invalid.", ex);
        }
    }

    internal static IReadOnlyList<RouteMatrixItem> ToItems(OpenRouteServiceMatrixResponse? payload, int expectedOrigins)
    {
        var distances = payload?.Distances ?? [];
        var durations = payload?.Durations ?? [];
        var items = new List<RouteMatrixItem>(expectedOrigins);

        for (var i = 0; i < expectedOrigins; i++)
        {
            var distance = i < distances.Length ? distances[i].FirstOrDefault() : null;
            var duration = i < durations.Length ? durations[i].FirstOrDefault() : null;
            items.Add(new RouteMatrixItem(i, ToNullableInt(distance), ToNullableInt(duration)));
        }

        return items;
    }

    private static int? ToNullableInt(double? value) =>
        value is null ? null : (int)Math.Round(value.Value);

    private static void ValidateRequest(IReadOnlyList<GeoPoint> origins, GeoPoint destination)
    {
        if (origins.Count == 0 || origins.Any(x => !x.IsValid) || !destination.IsValid)
            throw new RoutingInvalidLocationException();
    }
}

internal sealed record OpenRouteServiceMatrixRequest(
    [property: JsonPropertyName("locations")] double[][] Locations,
    [property: JsonPropertyName("sources")] int[] Sources,
    [property: JsonPropertyName("destinations")] int[] Destinations,
    [property: JsonPropertyName("metrics")] string[] Metrics,
    [property: JsonPropertyName("units")] string Units);

internal sealed record OpenRouteServiceMatrixResponse(
    [property: JsonPropertyName("distances")] double?[][]? Distances,
    [property: JsonPropertyName("durations")] double?[][]? Durations);
