using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Controllers.Grpc;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Startup;

internal static class NutritionServiceExtensions
{
    public static void AddNutritionServices(this WebApplicationBuilder builder, LocalDemoCatalogOptions localDemoCatalog)
    {
        var (jwtSecret, issuer, audience) = builder.Configuration.ReadNutritionJwtSettings();
        var peopleUrl = builder.Configuration["People:BaseUrl"] ?? "";
        var serviceKey = builder.Configuration["People:ServiceKey"] ?? "";
        if (!Uri.TryCreate(peopleUrl, UriKind.Absolute, out var peopleUri) || serviceKey.Length is not (>= 32 and <= 256) ||
            (peopleUri.Scheme != "https" && !builder.Environment.IsDevelopment()))
            throw new InvalidOperationException("People HTTPS endpoint and internal service key must be configured.");
        builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.Warning);
        builder.Logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
        builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 32768);
        var gatewayKey = builder.Configuration["Gateway:ServiceKey"] ?? "";
        if (gatewayKey.Length > 0 && gatewayKey.Length is not (>= 32 and <= 256))
            throw new InvalidOperationException("Gateway:ServiceKey must contain 32..256 characters.");
        builder.Services.AddGrpc(o =>
        {
            o.MaxReceiveMessageSize = 32768;
            o.MaxSendMessageSize = 1024 * 1024;
            o.Interceptors.Add<NutritionRpcInterceptor>();
        });

        builder.Services.AddNutritionAuthentication(jwtSecret, issuer, audience);

        builder.Services.AddSingleton<INutritionFeatures, NutritionFeatures>();
        builder.Services.AddSingleton(localDemoCatalog);
        builder.Services.AddSingleton(_ => NpgsqlDataSource.Create(builder.Configuration.GetConnectionString("Nutrition")
            ?? throw new InvalidOperationException("ConnectionStrings:Nutrition is required.")));
        builder.Services.AddSingleton(_ => new RecommendationLockDataSource(builder.Configuration.GetConnectionString("Nutrition")
            ?? throw new InvalidOperationException("ConnectionStrings:Nutrition is required.")));
        builder.Services.AddScoped<INutritionStore, NutritionStore>();
        builder.Services.AddNutritionOptions(builder.Configuration, builder.Environment);
        builder.Services.AddNutritionAi();
        builder.Services.AddScoped<AssessmentProcessor>();
        builder.Services.AddScoped<NutritionWriteScope>();
        builder.Services.AddScoped<MealPreparationService>();
        builder.Services.AddScoped<IMealRecommendationEngine, MealRecommendationEngine>();
        builder.Services.AddScoped<NutritionKnowledgeSearch>();
        builder.Services.AddOptions<NutritionReferenceOptions>()
            .Bind(builder.Configuration.GetSection("NutritionKnowledgeCorpus"));
        builder.Services.AddSingleton<INutritionReferenceLibrary, NutritionReferenceLibrary>();

        AddPeopleAndIdentityClients(builder.Services, builder.Configuration, peopleUrl, serviceKey);
        AddNutritionWorkers(builder.Services, builder.Configuration);

        builder.Services.AddMediatR(c => c.RegisterServicesFromAssemblyContaining<AssessmentProcessor>());
        builder.Services.AddNutritionHttp(builder.Configuration);
    }

    private static void AddPeopleAndIdentityClients(IServiceCollection services, IConfiguration configuration,
        string peopleUrl, string serviceKey)
    {
        services.AddHttpClient<IPeopleHealthClient, PeopleHealthClient>(client =>
        {
            client.BaseAddress = new Uri(peopleUrl.TrimEnd('/') + '/');
            client.DefaultRequestHeaders.Add("X-Nutrition-Service-Key", serviceKey);
            client.Timeout = TimeSpan.FromSeconds(5);
        }).ConfigurePrimaryHttpMessageHandler(() =>
            InternalCertificateTrust.CreateHandler(configuration["People:TrustedRootCertificatePath"]));
        services.AddHttpClient<IIdentitySessionClient, IdentitySessionClient>(client =>
        {
            client.BaseAddress = new Uri(peopleUrl.TrimEnd('/') + '/');
            client.Timeout = TimeSpan.FromSeconds(5);
        }).ConfigurePrimaryHttpMessageHandler(() =>
            InternalCertificateTrust.CreateHandler(configuration["People:TrustedRootCertificatePath"]));
    }

    private static void AddNutritionWorkers(IServiceCollection services, IConfiguration configuration)
    {
        services.AddHostedService<NutritionWorker>();
        if (configuration.GetValue<bool>("BeneficiaryEvents:Enabled"))
        {
            foreach (var key in new[] { "BootstrapServers", "Topic", "ConsumerGroup", "DlqTopic" })
                if (string.IsNullOrWhiteSpace(configuration[$"BeneficiaryEvents:{key}"]))
                    throw new InvalidOperationException($"BeneficiaryEvents:{key} is required when enabled.");
            services.AddSingleton<BeneficiaryDeletionProcessor>();
            services.AddHostedService<BeneficiaryDeletionConsumer>();
        }
    }
}
