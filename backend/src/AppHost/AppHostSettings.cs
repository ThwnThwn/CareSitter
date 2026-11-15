using Aspire.Hosting.ApplicationModel;
using CareSitter.AppHost.Extensions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace CareSitter.AppHost;

internal sealed class AppHostSettings
{
    private AppHostSettings(IDistributedApplicationBuilder builder, string repositoryPath, string apiEnvFile)
    {
        Configuration = builder.Configuration;
        RepositoryPath = repositoryPath;
        ApiEnvFile = apiEnvFile;
        DisableIpv6 = builder.Environment.IsDevelopment() && Configuration.GetValue<bool>("AppHost:DisableIpv6");
        JwtKey = builder.AddSecret("identity-jwt-key", Configuration.Required("Jwt:SecretKey"));
        CoreConnection = builder.AddSecret("care-db-connection", Configuration.Required("ConnectionStrings:CareSitter"));
        RedisConnection = builder.AddSecret("auth-cache-connection", Configuration.Required("Redis:ConnectionString"));
        NutritionRuntimePassword = builder.AddParameter("nutrition-runtime-password", secret: true);
        NutritionGatewayKey = builder.AddParameter("nutrition-gateway-key", secret: true);
        NutritionPeopleKey = builder.AddParameter("nutrition-people-key", secret: true);
    }

    public IConfiguration Configuration { get; }
    public string RepositoryPath { get; }
    public string ApiEnvFile { get; }
    public bool DisableIpv6 { get; }
    public IResourceBuilder<ParameterResource> JwtKey { get; }
    public IResourceBuilder<ParameterResource> CoreConnection { get; }
    public IResourceBuilder<ParameterResource> RedisConnection { get; }
    public IResourceBuilder<ParameterResource> NutritionRuntimePassword { get; }
    public IResourceBuilder<ParameterResource> NutritionGatewayKey { get; }
    public IResourceBuilder<ParameterResource> NutritionPeopleKey { get; }

    public static AppHostSettings Load(IDistributedApplicationBuilder builder, string[] args)
    {
        var repository = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, "../../.."));
        var apiEnvFile = LocalConfiguration.Load(builder.Configuration, builder.AppHostDirectory, repository);
        builder.Configuration.AddCommandLine(args);
        return new AppHostSettings(builder, repository, apiEnvFile);
    }
}
