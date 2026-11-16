using Aspire.Hosting.ApplicationModel;
using Microsoft.Extensions.Configuration;

namespace CareSitter.AppHost.Extensions;

internal static class NutritionResourceExtensions
{
    public static async Task<IResourceBuilder<ProjectResource>> AddNutritionServiceAsync(
        this IDistributedApplicationBuilder builder, AppHostSettings settings, IResourceBuilder<ProjectResource> api)
    {
        var configuration = settings.Configuration;
        var nutrition = builder.AddProject<Projects.CareSitter_Nutrition>("nutrition", launchProfileName: null)
            .WithHttpEndpoint(port: configuration.GetValue("AppHost:NutritionHttpPort", 5035), name: "http", isProxied: false)
            .WithHttpEndpoint(port: configuration.GetValue("AppHost:NutritionGrpcPort", 5036), name: "grpc", isProxied: false)
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("CARESITTER_ENV_FILE", settings.ApiEnvFile)
            .WithEnvironment("Jwt__SecretKey", settings.JwtKey)
            .WithEnvironment("Jwt__Issuer", configuration.Required("Jwt:Issuer"))
            .WithEnvironment("Jwt__Audience", configuration.Required("Jwt:Audience"))
            .WithEnvironment("Gateway__ServiceKey", settings.NutritionGatewayKey)
            .WithEnvironment("People__ServiceKey", settings.NutritionPeopleKey)
            .WithEnvironment("People__BaseUrl", api.GetEndpoint("http"))
            .WithEnvironment("Kestrel__Endpoints__Http__Protocols", "Http1")
            .WithEnvironment("Kestrel__Endpoints__Grpc__Protocols", "Http2")
            .WithHttpHealthCheck("/health/ready", endpointName: "http");

        if (settings.DisableIpv6) nutrition.WithEnvironment("DOTNET_SYSTEM_NET_DISABLEIPV6", "1");
        await builder.AddNutritionDatabaseAsync(settings, nutrition);
        nutrition.WithEnvironment("Kestrel__Endpoints__Http__Url", nutrition.GetEndpoint("http"));
        nutrition.WithEnvironment("Kestrel__Endpoints__Grpc__Url", nutrition.GetEndpoint("grpc"));
        api.WithEnvironment("NutritionGateway__GrpcUrl", nutrition.GetEndpoint("grpc"));

        return nutrition;
    }
}
