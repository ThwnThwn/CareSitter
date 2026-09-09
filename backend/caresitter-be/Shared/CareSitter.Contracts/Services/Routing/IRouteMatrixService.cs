namespace CareSitter.Contracts.Services.Routing;

public interface IRouteMatrixService
{
    Task<IReadOnlyList<RouteMatrixItem>> CalculateAsync(
        IReadOnlyList<GeoPoint> origins,
        GeoPoint destination,
        CancellationToken ct = default);
}
