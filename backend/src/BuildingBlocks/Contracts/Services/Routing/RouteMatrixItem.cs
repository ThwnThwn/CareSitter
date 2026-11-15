namespace CareSitter.Contracts.Services.Routing;

public sealed record RouteMatrixItem(
    int OriginIndex,
    int? DistanceMeters,
    int? DurationSeconds)
{
    public bool IsRoutable => DistanceMeters is not null && DurationSeconds is not null;
}
