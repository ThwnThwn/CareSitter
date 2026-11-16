using CareSitter.ApiHost.Routing.Geoapify;
using CareSitter.ApiHost.Routing.OpenRouteService;
using CareSitter.Contracts.Services.Routing;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Routing;

internal static class RoutingExtensions
{
    public static void AddApiRouting(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<RoutingOptions>(configuration.GetSection("Routing"));
        services.AddMetrics();
        services.AddSingleton<RoutingMetrics>();
        services.AddHttpClient<GeoapifyRouteMatrixService>((sp, client) =>
        {
            var config = sp.GetRequiredService<IOptions<RoutingOptions>>().Value.Geoapify;
            client.BaseAddress = new Uri(string.IsNullOrWhiteSpace(config.BaseUrl)
                ? "https://api.geoapify.com"
                : config.BaseUrl);
        });
        services.AddHttpClient<OpenRouteServiceMatrixService>((sp, client) =>
        {
            var config = sp.GetRequiredService<IOptions<RoutingOptions>>().Value.OpenRouteService;
            client.BaseAddress = new Uri(string.IsNullOrWhiteSpace(config.BaseUrl)
                ? "https://api.openrouteservice.org"
                : config.BaseUrl);
            var apiKey = sp.GetRequiredService<IConfiguration>()["ORS_API_KEY"]
                ?? sp.GetRequiredService<IConfiguration>()["OpenRouteService:ApiKey"];
            if (!string.IsNullOrWhiteSpace(apiKey))
                client.DefaultRequestHeaders.Add("Authorization", apiKey);
        });
        services.AddScoped<ResilientRouteMatrixService>();
        services.AddScoped<IRouteMatrixService>(sp =>
        {
            var config = sp.GetRequiredService<IOptions<RoutingOptions>>().Value;
            if (config.EnableBackupProvider || string.Equals(config.Provider, "Resilient", StringComparison.OrdinalIgnoreCase))
                return sp.GetRequiredService<ResilientRouteMatrixService>();
            if (string.Equals(config.Provider, "OpenRouteService", StringComparison.OrdinalIgnoreCase))
                return sp.GetRequiredService<OpenRouteServiceMatrixService>();
            return sp.GetRequiredService<GeoapifyRouteMatrixService>();
        });
        services.AddExceptionHandler<RoutingExceptionHandler>();
    }
}
