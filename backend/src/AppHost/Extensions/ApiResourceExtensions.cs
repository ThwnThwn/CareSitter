using Aspire.Hosting.ApplicationModel;
using Microsoft.Extensions.Configuration;

namespace CareSitter.AppHost.Extensions;

internal static class ApiResourceExtensions
{
    public static IResourceBuilder<ProjectResource> AddCareSitterApi(this IDistributedApplicationBuilder builder,
        AppHostSettings settings)
    {
        var configuration = settings.Configuration;
        var port = configuration.GetValue("AppHost:ApiPort", 5033);
        var listenUrl = $"http://0.0.0.0:{port}";
        var api = builder.AddProject<Projects.CareSitter_ApiHost>("api", launchProfileName: null)
            .WithHttpEndpoint(port: port, name: "http", isProxied: false)
            // ngrok reaches Kestrel through host.docker.internal, outside the loopback interface.
            .WithEnvironment("Kestrel__Endpoints__Http__Url", listenUrl)
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("CARESITTER_ENV_FILE", settings.ApiEnvFile)
            .WithEnvironment("ConnectionStrings__CareSitter", settings.CoreConnection)
            .WithEnvironment("Redis__ConnectionString", settings.RedisConnection)
            .WithEnvironment("Jwt__SecretKey", settings.JwtKey)
            .WithEnvironment("Jwt__Issuer", configuration.Required("Jwt:Issuer"))
            .WithEnvironment("Jwt__Audience", configuration.Required("Jwt:Audience"))
            .WithEnvironment("NutritionIntegration__ServiceKey", settings.NutritionPeopleKey)
            .WithEnvironment("NutritionGateway__Enabled", "true")
            .WithEnvironment("NutritionGateway__ServiceKey", settings.NutritionGatewayKey)
            .WithHttpHealthCheck("/health/live");
        if (settings.DisableIpv6) api.WithEnvironment("DOTNET_SYSTEM_NET_DISABLEIPV6", "1");
        return api;
    }
}
