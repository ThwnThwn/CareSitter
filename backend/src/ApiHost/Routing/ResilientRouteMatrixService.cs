using CareSitter.Contracts.Services.Routing;

namespace CareSitter.ApiHost.Routing;

public sealed class ResilientRouteMatrixService(
    Geoapify.GeoapifyRouteMatrixService primary,
    OpenRouteService.OpenRouteServiceMatrixService backup,
    ILogger<ResilientRouteMatrixService> logger) : IRouteMatrixService
{
    public async Task<IReadOnlyList<RouteMatrixItem>> CalculateAsync(
        IReadOnlyList<GeoPoint> origins,
        GeoPoint destination,
        CancellationToken ct = default)
    {
        try
        {
            return await primary.CalculateAsync(origins, destination, ct);
        }
        catch (RoutingLimitExceededException ex)
        {
            logger.LogWarning(ex, "Geoapify routing quota exceeded. Falling back to OpenRouteService.");
            return await backup.CalculateAsync(origins, destination, ct);
        }
        catch (RoutingProviderUnavailableException ex)
        {
            logger.LogWarning(ex, "Geoapify routing unavailable. Falling back to OpenRouteService.");
            return await backup.CalculateAsync(origins, destination, ct);
        }
    }
}
