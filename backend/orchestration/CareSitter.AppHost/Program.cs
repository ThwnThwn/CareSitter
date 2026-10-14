using Aspire.Hosting.ApplicationModel;
using CareSitter.AppHost;
using Microsoft.Extensions.Configuration;

var builder = DistributedApplication.CreateBuilder(args);
var appHostDirectory = builder.AppHostDirectory;
var repository = Path.GetFullPath(Path.Combine(appHostDirectory, "../../.."));
var apiEnvFile = LocalConfiguration.Load(builder.Configuration, appHostDirectory, repository);
builder.Configuration.AddCommandLine(args);

string Required(string key) => !string.IsNullOrWhiteSpace(builder.Configuration[key])
    ? builder.Configuration[key]! : throw new InvalidOperationException($"Configure {key} in the API environment or AppHost configuration.");

IResourceBuilder<ParameterResource> Secret(string name, string value)
{
    builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
    {
        [$"Parameters:{name}"] = builder.Configuration[$"Parameters:{name}"] ?? value
    });
    return builder.AddParameter(name, secret: true);
}

var jwtKey = Secret("identity-jwt-key", Required("Jwt:SecretKey"));
var jwtIssuer = Required("Jwt:Issuer");
var jwtAudience = Required("Jwt:Audience");
var coreConnection = Secret("care-db-connection", Required("ConnectionStrings:CareSitter"));
var redisConnection = Secret("auth-cache-connection", Required("Redis:ConnectionString"));
var adminPassword = builder.AddParameter("nutrition-admin-password", secret: true);
var runtimePassword = builder.AddParameter("nutrition-runtime-password", secret: true);
var gatewayKey = builder.AddParameter("nutrition-gateway-key", secret: true);
var peopleKey = builder.AddParameter("nutrition-people-key", secret: true);

var postgres = builder.AddPostgres("nutrition-db", password: adminPassword)
    .WithImageTag("16")
    .WithEnvironment("POSTGRES_DB", "nutrition")
    .WithEnvironment("NUTRITION_DB_APP_PASSWORD", runtimePassword)
    .WithBindMount(Path.Combine(repository, "backend/init-db/nutrition-service/01-nutrition-workflow.sql"),
        "/docker-entrypoint-initdb.d/01-schema.sql", isReadOnly: true)
    .WithBindMount(Path.Combine(repository, "backend/init-db/nutrition-service/02-runtime-role.sql"), "/runtime-role.sql", isReadOnly: true)
    .WithBindMount(Path.Combine(repository, "backend/services/nutrition/scripts/02-runtime-role.sh"),
        "/docker-entrypoint-initdb.d/02-runtime-role.sh", isReadOnly: true)
    .WithDataVolume(builder.Configuration["AppHost:NutritionDataVolume"] ?? "caresitter-apphost-nutrition");
var nutritionDatabase = postgres.AddDatabase("nutrition-store", databaseName: "nutrition");

var api = builder.AddProject<Projects.CareSitter_ApiHost>("api", launchProfileName: null)
    .WithHttpEndpoint(port: builder.Configuration.GetValue("AppHost:ApiPort", 5033), name: "http", isProxied: false)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
    .WithEnvironment("CARESITTER_ENV_FILE", apiEnvFile)
    .WithEnvironment("ConnectionStrings__CareSitter", coreConnection)
    .WithEnvironment("Redis__ConnectionString", redisConnection)
    .WithEnvironment("Jwt__SecretKey", jwtKey)
    .WithEnvironment("Jwt__Issuer", jwtIssuer)
    .WithEnvironment("Jwt__Audience", jwtAudience)
    .WithEnvironment("NutritionIntegration__ServiceKey", peopleKey)
    .WithEnvironment("NutritionGateway__Enabled", "true")
    .WithEnvironment("NutritionGateway__ServiceKey", gatewayKey)
    .WithHttpHealthCheck("/health/live");

var nutrition = builder.AddProject<Projects.CareSitter_Nutrition>("nutrition", launchProfileName: null)
    .WithHttpEndpoint(port: builder.Configuration.GetValue("AppHost:NutritionHttpPort", 5035), name: "http", isProxied: false)
    .WithHttpEndpoint(port: builder.Configuration.GetValue("AppHost:NutritionGrpcPort", 5036), name: "grpc", isProxied: false)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
    .WithEnvironment("Jwt__SecretKey", jwtKey)
    .WithEnvironment("Jwt__Issuer", jwtIssuer)
    .WithEnvironment("Jwt__Audience", jwtAudience)
    .WithEnvironment("Gateway__ServiceKey", gatewayKey)
    .WithEnvironment("People__ServiceKey", peopleKey)
    .WithEnvironment("People__BaseUrl", api.GetEndpoint("http"))
    .WithEnvironment("ConnectionStrings__Nutrition", ReferenceExpression.Create(
        $"Host={postgres.GetEndpoint("tcp").Property(EndpointProperty.Host)};Port={postgres.GetEndpoint("tcp").Property(EndpointProperty.Port)};Database=nutrition;Username=nutrition_app;Password={runtimePassword}"))
    .WithEnvironment("Nutrition__Enabled", builder.Configuration.GetValue("Nutrition:Enabled", false).ToString())
    .WithEnvironment("Nutrition__AssessmentsEnabled", builder.Configuration.GetValue("Nutrition:AssessmentsEnabled", false).ToString())
    .WithEnvironment("Nutrition__RecommendationsEnabled", builder.Configuration.GetValue("Nutrition:RecommendationsEnabled", false).ToString())
    .WithEnvironment("Kestrel__Endpoints__Http__Protocols", "Http1")
    .WithEnvironment("Kestrel__Endpoints__Grpc__Protocols", "Http2")
    .WithHttpHealthCheck("/health/ready", endpointName: "http")
    .WaitFor(nutritionDatabase);

nutrition.WithEnvironment("Kestrel__Endpoints__Http__Url", nutrition.GetEndpoint("http"));
nutrition.WithEnvironment("Kestrel__Endpoints__Grpc__Url", nutrition.GetEndpoint("grpc"));
api.WithEnvironment("NutritionGateway__GrpcUrl", nutrition.GetEndpoint("grpc"));
api.WaitFor(nutrition);

if (builder.Configuration.GetValue<bool>("KAFKA_ENABLED") && builder.Configuration.GetValue<bool>("KAFKA_FLOW_NOTIFICATIONS_ENABLED"))
{
    var worker = builder.AddProject<Projects.CareSitter_NotificationWorker>("notification-worker", launchProfileName: null)
        .WithHttpEndpoint(name: "http")
        .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
        .WithEnvironment("KAFKA_SUPPORT_API_URL", api.GetEndpoint("http"))
        .WithHttpHealthCheck("/health/live")
        .WaitFor(api);
    foreach (var key in new[] { "KAFKA_ENABLED", "KAFKA_FLOW_NOTIFICATIONS_ENABLED", "KAFKA_BOOTSTRAP_SERVERS", "KAFKA_CLIENT_ID", "KAFKA_TOPIC_NOTIFICATIONS", "KAFKA_TOPIC_PAYMENTS",
                 "KAFKA_TOPIC_NUTRITION", "KAFKA_INTERNAL_SERVICE_KEY", "Firebase:ServiceAccountPath", "Firebase:ServiceAccountJson", "Smtp:Host",
                 "Smtp:Port", "Smtp:UserName", "Smtp:Password", "Smtp:FromName", "Smtp:TimeoutSeconds" })
        if (builder.Configuration[key] is { } value)
        {
            var sensitive = key is "KAFKA_INTERNAL_SERVICE_KEY" or "Firebase:ServiceAccountJson" or "Smtp:Password";
            if (sensitive) worker.WithEnvironment(key.Replace(":", "__"), Secret("worker-" + key.ToLowerInvariant().Replace(":", "-").Replace("_", "-"), value));
            else worker.WithEnvironment(key.Replace(":", "__"), value);
        }
}

builder.Build().Run();
