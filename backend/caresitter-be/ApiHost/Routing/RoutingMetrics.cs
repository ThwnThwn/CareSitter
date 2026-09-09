using System.Diagnostics.Metrics;

namespace CareSitter.ApiHost.Routing;

public sealed class RoutingMetrics
{
    private readonly Counter<long> _requests;
    private readonly Counter<long> _successes;
    private readonly Counter<long> _failures;
    private readonly Counter<long> _rateLimits;
    private readonly Counter<long> _matrixCells;
    private readonly Counter<long> _nullRoutes;
    private readonly Histogram<double> _latencyMs;

    public RoutingMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create("CareSitter.Routing");
        _requests = meter.CreateCounter<long>("routing_requests_total");
        _successes = meter.CreateCounter<long>("routing_success_total");
        _failures = meter.CreateCounter<long>("routing_failure_total");
        _rateLimits = meter.CreateCounter<long>("routing_429_total");
        _matrixCells = meter.CreateCounter<long>("routing_matrix_cells_total");
        _nullRoutes = meter.CreateCounter<long>("routing_null_routes_total");
        _latencyMs = meter.CreateHistogram<double>("routing_latency_ms");
    }

    public void Request(string provider, int cells)
    {
        _requests.Add(1, Tag("provider", provider));
        _matrixCells.Add(cells, Tag("provider", provider));
    }

    public void Success(string provider, int nullRoutes, double latencyMs)
    {
        _successes.Add(1, Tag("provider", provider));
        _nullRoutes.Add(nullRoutes, Tag("provider", provider));
        _latencyMs.Record(latencyMs, Tag("provider", provider));
    }

    public void RateLimited(string provider) =>
        _rateLimits.Add(1, Tag("provider", provider));

    public void Failure(string provider, string reason)
    {
        _failures.Add(1,
            Tag("provider", provider),
            Tag("reason", reason));
    }

    private static KeyValuePair<string, object?> Tag(string name, string value) => new(name, value);
}
