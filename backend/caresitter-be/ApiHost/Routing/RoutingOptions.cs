namespace CareSitter.ApiHost.Routing;

public sealed class RoutingOptions
{
    public string Provider { get; set; } = "Geoapify";
    public int CandidateLimit { get; set; } = 10;
    public bool EnableBackupProvider { get; set; } = false;
    public RoutingProviderOptions Geoapify { get; set; } = new();
    public RoutingProviderOptions OpenRouteService { get; set; } = new();
}

public sealed class RoutingProviderOptions
{
    public string BaseUrl { get; set; } = "";
    public string Mode { get; set; } = "drive";
    public string Profile { get; set; } = "driving-car";
    public string Traffic { get; set; } = "free_flow";
    public int TimeoutSeconds { get; set; } = 5;
}
