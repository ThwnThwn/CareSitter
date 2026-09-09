using CareSitter.ApiHost.Routing.Geoapify;
using CareSitter.ApiHost.Routing.OpenRouteService;
using CareSitter.Contracts.Services.Routing;

namespace CareSitter.Modules.Routing.UnitTests;

public class RouteMatrixParsingTests
{
    [Fact]
    public void GeoPoint_WithLongitudeLatitudeBounds_ShouldValidateCoordinates()
    {
        Assert.True(new GeoPoint(10.7769, 106.7009).IsValid);
        Assert.False(new GeoPoint(91, 106.7009).IsValid);
        Assert.False(new GeoPoint(10.7769, 181).IsValid);
    }

    [Fact]
    public void Geoapify_ToItems_ShouldMapDistanceTimeAndKeepNullRoute()
    {
        var payload = new GeoapifyMatrixResponse([
            [new GeoapifyMatrixCell(1234.4, 555.5)],
            [new GeoapifyMatrixCell(null, null)]
        ]);

        var result = GeoapifyRouteMatrixService.ToItems(payload, expectedOrigins: 2);

        Assert.Equal(2, result.Count);
        Assert.Equal(0, result[0].OriginIndex);
        Assert.Equal(1234, result[0].DistanceMeters);
        Assert.Equal(556, result[0].DurationSeconds);
        Assert.True(result[0].IsRoutable);
        Assert.False(result[1].IsRoutable);
    }

    [Fact]
    public void OpenRouteService_ToItems_ShouldMapDistanceDurationAndKeepNullRoute()
    {
        var payload = new OpenRouteServiceMatrixResponse(
            Distances: [
                [2300.2],
                [null]
            ],
            Durations: [
                [701.6],
                [null]
            ]);

        var result = OpenRouteServiceMatrixService.ToItems(payload, expectedOrigins: 2);

        Assert.Equal(2, result.Count);
        Assert.Equal(2300, result[0].DistanceMeters);
        Assert.Equal(702, result[0].DurationSeconds);
        Assert.True(result[0].IsRoutable);
        Assert.False(result[1].IsRoutable);
    }

    [Fact]
    public void MatrixParsers_WhenRowsMissing_ShouldReturnNullRoutesForMissingOrigins()
    {
        var payload = new GeoapifyMatrixResponse([
            [new GeoapifyMatrixCell(1000, 300)]
        ]);

        var result = GeoapifyRouteMatrixService.ToItems(payload, expectedOrigins: 3);

        Assert.True(result[0].IsRoutable);
        Assert.False(result[1].IsRoutable);
        Assert.False(result[2].IsRoutable);
    }
}
