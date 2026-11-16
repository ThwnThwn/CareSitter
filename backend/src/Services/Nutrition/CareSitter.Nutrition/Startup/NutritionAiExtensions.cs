using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Startup;

internal static class NutritionAiExtensions
{
    public static void AddNutritionAi(this IServiceCollection services)
    {
        services.AddSingleton<HealthParserRuntimeGuard>();
        services.AddSingleton<MealRankingRuntimeGuard>();
        services.AddScoped<UnconfiguredHealthParser>();
        services.AddHttpClient<OpenAiHealthDescriptionParser>((services, client) =>
        {
            var options = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
            client.BaseAddress = new Uri(options.EffectiveBaseUrl.TrimEnd('/') + '/');
            client.Timeout = Timeout.InfiniteTimeSpan;
        });
        services.AddHttpClient<GeminiHealthDescriptionParser>((services, client) =>
        {
            var options = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
            client.BaseAddress = new Uri(options.EffectiveBaseUrl.TrimEnd('/') + '/');
            client.Timeout = Timeout.InfiniteTimeSpan;
        });
        services.AddScoped<IHealthDescriptionParser>(services =>
        {
            var options = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
            if (!options.Enabled) return services.GetRequiredService<UnconfiguredHealthParser>();
            return HealthParserProviders.IsGemini(options.Provider)
                ? services.GetRequiredService<GeminiHealthDescriptionParser>()
                : services.GetRequiredService<OpenAiHealthDescriptionParser>();
        });

        services.AddScoped<UnavailableMealKnowledgeRetriever>();
        services.AddScoped<ReleasedGraphMealKnowledgeRetriever>();
        services.AddScoped<ReleasedRetrievalMealKnowledgeRetriever>();
        services.AddScoped<OwnerAuthorizedCorpusMealKnowledgeRetriever>();
        services.AddScoped<OwnerAuthorizedGraphMealKnowledgeRetriever>();
        services.AddScoped<IMealKnowledgeRetriever>(services =>
        {
            var options = services.GetRequiredService<IOptions<MealGroundingOptions>>().Value;
            if (!options.Enabled) return services.GetRequiredService<UnavailableMealKnowledgeRetriever>();
            return options.Mode switch
            {
                MealGroundingOptions.ReleasedRetrievalMode => services.GetRequiredService<ReleasedRetrievalMealKnowledgeRetriever>(),
                MealGroundingOptions.OwnerAuthorizedCorpusDemoMode => services.GetRequiredService<OwnerAuthorizedCorpusMealKnowledgeRetriever>(),
                MealGroundingOptions.OwnerAuthorizedGraphDemoMode => services.GetRequiredService<OwnerAuthorizedGraphMealKnowledgeRetriever>(),
                _ => services.GetRequiredService<ReleasedGraphMealKnowledgeRetriever>()
            };
        });

        services.AddScoped<UnavailableMealCandidateRanker>();
        services.AddHttpClient<GeminiMealCandidateRanker>((services, client) =>
        {
            var options = services.GetRequiredService<IOptions<MealRankingOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + '/');
            client.Timeout = Timeout.InfiniteTimeSpan;
        });
        services.AddScoped<IMealCandidateRanker>(services =>
            services.GetRequiredService<IOptions<MealRankingOptions>>().Value.Enabled
                ? services.GetRequiredService<GeminiMealCandidateRanker>()
                : services.GetRequiredService<UnavailableMealCandidateRanker>());

        services.AddHttpClient<GeminiKnowledgeAnswer>(client =>
        {
            client.BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/");
            client.Timeout = Timeout.InfiniteTimeSpan;
        }).ConfigurePrimaryHttpMessageHandler(services =>
            services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value.UseWindowsCurl
                ? new WindowsGeminiDemoHandler()
                : new HttpClientHandler { AllowAutoRedirect = false });
        services.AddHttpClient<LocalKnowledgeAnswer>(client =>
        {
            client.BaseAddress = new Uri("http://127.0.0.1:11434/");
            client.Timeout = TimeSpan.FromSeconds(12);
        }).ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
        {
            AllowAutoRedirect = false,
            UseProxy = false
        });
    }
}
