using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using CareSitter.Contracts.Services.Routing;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Routing.Geoapify;

public sealed class GeoapifyRouteMatrixService(
    HttpClient httpClient,
    IConfiguration configuration,
    IOptions<RoutingOptions> options,
    RoutingMetrics metrics,
    ILogger<GeoapifyRouteMatrixService> logger) : IRouteMatrixService
{
    private const string Provider = "geoapify";
    private RoutingProviderOptions Config => options.Value.Geoapify;

    public async Task<IReadOnlyList<RouteMatrixItem>> CalculateAsync(
        IReadOnlyList<GeoPoint> origins,
        GeoPoint destination,
        CancellationToken ct = default)
    {
        ValidateRequest(origins, destination);
        var apiKey = configuration["GEOAPIFY_API_KEY"] ?? configuration["Geoapify:ApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new RoutingProviderUnavailableException("Geoapify API key is not configured.");

        var request = new GeoapifyMatrixRequest(
            Mode: string.IsNullOrWhiteSpace(Config.Mode) ? "drive" : Config.Mode,
            Sources: origins.Select(x => new GeoapifyLocation([x.Longitude, x.Latitude])).ToArray(),
            Targets: [new GeoapifyLocation([destination.Longitude, destination.Latitude])],
            Traffic: string.IsNullOrWhiteSpace(Config.Traffic) ? null : Config.Traffic);

        metrics.Request(Provider, origins.Count);
        var stopwatch = Stopwatch.StartNew();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(Math.Max(1, Config.TimeoutSeconds)));

        try
        {
            using var response = await httpClient.PostAsJsonAsync(
                $"/v1/routematrix?apiKey={Uri.EscapeDataString(apiKey)}",
                request,
                timeout.Token);

            if (response.StatusCode == HttpStatusCode.TooManyRequests)
            {
                metrics.RateLimited(Provider);
                throw new RoutingLimitExceededException("Geoapify quota exceeded.");
            }

            if ((int)response.StatusCode >= 500)
            {
                metrics.Failure(Provider, $"http_{(int)response.StatusCode}");
                throw new RoutingProviderUnavailableException($"Geoapify returned {(int)response.StatusCode}.");
            }

            if (response.StatusCode == HttpStatusCode.BadRequest ||
                response.StatusCode == HttpStatusCode.UnprocessableEntity)
            {
                metrics.Failure(Provider, $"http_{(int)response.StatusCode}");
                throw new RoutingInvalidLocationException("Geoapify rejected the routing coordinates.");
            }

            if (!response.IsSuccessStatusCode)
            {
                metrics.Failure(Provider, $"http_{(int)response.StatusCode}");
                throw new RoutingProviderUnavailableException($"Geoapify returned {(int)response.StatusCode}.");
            }

            var payload = await response.Content.ReadFromJsonAsync<GeoapifyMatrixResponse>(cancellationToken: timeout.Token);
            var items = ToItems(payload, origins.Count);
            metrics.Success(Provider, items.Count(x => !x.IsRoutable), stopwatch.Elapsed.TotalMilliseconds);
            logger.LogInformation("Geoapify route matrix succeeded for {Origins} origins.", origins.Count);
            return items;
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            metrics.Failure(Provider, "timeout");
            throw new RoutingProviderUnavailableException("Geoapify route matrix timed out.");
        }
        catch (HttpRequestException)
        {
            metrics.Failure(Provider, "network");
            throw new RoutingProviderUnavailableException("Geoapify route matrix request failed.");
        }
        catch (JsonException)
        {
            metrics.Failure(Provider, "invalid_response");
            throw new RoutingProviderUnavailableException("Geoapify route matrix response was invalid.");
        }
    }

    internal static IReadOnlyList<RouteMatrixItem> ToItems(GeoapifyMatrixResponse? payload, int expectedOrigins)
    {
        var rows = payload?.SourcesToTargets ?? [];
        var items = new List<RouteMatrixItem>(expectedOrigins);

        for (var i = 0; i < expectedOrigins; i++)
        {
            var cell = i < rows.Length ? rows[i].FirstOrDefault() : null;
            items.Add(new RouteMatrixItem(i, ToNullableInt(cell?.Distance), ToNullableInt(cell?.Time)));
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

internal sealed record GeoapifyMatrixRequest(
    [property: JsonPropertyName("mode")] string Mode,
    [property: JsonPropertyName("sources")] IReadOnlyList<GeoapifyLocation> Sources,
    [property: JsonPropertyName("targets")] IReadOnlyList<GeoapifyLocation> Targets,
    [property: JsonPropertyName("traffic")] string? Traffic);

internal sealed record GeoapifyLocation(
    [property: JsonPropertyName("location")] double[] Location);

internal sealed record GeoapifyMatrixResponse(
    [property: JsonPropertyName("sources_to_targets")] GeoapifyMatrixCell[][]? SourcesToTargets);

internal sealed record GeoapifyMatrixCell(
    [property: JsonPropertyName("distance")] double? Distance,
    [property: JsonPropertyName("time")] double? Time);
