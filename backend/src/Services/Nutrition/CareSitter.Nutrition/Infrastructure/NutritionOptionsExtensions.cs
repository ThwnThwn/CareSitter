using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal static class NutritionOptionsExtensions
{
    public static IServiceCollection AddNutritionOptions(this IServiceCollection services,
        IConfiguration configuration, IHostEnvironment environment)
    {
        services.AddSingleton<IValidateOptions<HealthParserOptions>, HealthParserOptionsValidator>();
        services.AddOptions<HealthParserOptions>()
            .Bind(configuration.GetSection(HealthParserOptions.SectionName))
            .ValidateOnStart();
        services.AddSingleton<IValidateOptions<MealGroundingOptions>, MealGroundingOptionsValidator>();
        services.AddOptions<MealGroundingOptions>()
            .Bind(configuration.GetSection(MealGroundingOptions.SectionName))
            .ValidateOnStart();
        services.AddSingleton<IValidateOptions<MealRankingOptions>, MealRankingOptionsValidator>();
        services.AddOptions<MealRankingOptions>()
            .Bind(configuration.GetSection(MealRankingOptions.SectionName))
            .PostConfigure(options =>
            {
                if (options.Enabled && string.IsNullOrWhiteSpace(options.ApiKey) && string.IsNullOrWhiteSpace(options.ApiKeyFile))
                    options.ApiKey = GeminiFallbackKey(configuration);
            })
            .ValidateOnStart();
        services.AddOptions<KnowledgeAnswerAiOptions>()
            .Bind(configuration.GetSection(KnowledgeAnswerAiOptions.SectionName))
            .PostConfigure(options =>
            {
                options.Model = configuration["NutritionKnowledgeAi:Model"] ??
                    configuration["MealRanking:Model"] ?? HealthParserProviders.GeminiModel;
                if (options.Enabled && string.IsNullOrWhiteSpace(options.ApiKey))
                    options.ApiKey = GeminiFallbackKey(configuration);
            })
            .Validate(options => !options.Enabled || options.DataProcessingApproved && !string.IsNullOrWhiteSpace(options.ApiKey),
                "NutritionKnowledgeAi requires an API key and approved external processing when enabled.")
            .Validate(options => !options.UseWindowsCurl || environment.IsDevelopment() && OperatingSystem.IsWindows(),
                "NutritionKnowledgeAi Windows transport is restricted to Windows Development.")
            .ValidateOnStart();
        return services;
    }

    private static string GeminiFallbackKey(IConfiguration configuration) =>
        HealthParserProviders.IsGemini(configuration["HealthParser:Provider"] ?? "")
            ? configuration["HealthParser:ApiKey"] ?? "" : "";
}
