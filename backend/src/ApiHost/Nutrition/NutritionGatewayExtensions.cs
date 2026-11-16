using CareSitter.Contracts.Nutrition;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Nutrition;

internal static class NutritionGatewayExtensions
{
    public static void AddNutritionGateway(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<NutritionGatewayOptions>().Bind(builder.Configuration.GetSection("NutritionGateway"))
            .Validate(options => options.IsValid(builder.Environment.IsDevelopment()),
                "NutritionGateway requires an internal gRPC endpoint, service credential and a bounded timeout.")
            .ValidateOnStart();
        builder.Services.AddSingleton<INutritionGateway, NutritionGrpcGateway>();
        builder.Services.AddScoped<IMealPlanSnapshotReader, MealPlanSnapshotReader>();
        builder.Services.AddHttpClient<NutritionReadinessHealthCheck>()
            .ConfigurePrimaryHttpMessageHandler(serviceProvider =>
                InternalCertificateTrust.CreateHandler(serviceProvider
                    .GetRequiredService<IOptions<NutritionGatewayOptions>>().Value.TrustedRootCertificatePath));
        builder.Services.AddOptions<NutritionKnowledgeOptions>()
            .Bind(builder.Configuration.GetSection("NutritionKnowledge"))
            .ValidateOnStart();
    }
}
