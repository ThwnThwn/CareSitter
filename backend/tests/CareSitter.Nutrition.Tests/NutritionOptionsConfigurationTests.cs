using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class NutritionOptionsConfigurationTests
{
    [Fact]
    public void Standalone_defaults_remain_disabled_and_keep_existing_runtime_limits()
    {
        using var services = Build();
        var parser = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
        var ranking = services.GetRequiredService<IOptions<MealRankingOptions>>().Value;
        var grounding = services.GetRequiredService<IOptions<MealGroundingOptions>>().Value;
        var knowledge = services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value;

        Assert.False(parser.Enabled);
        Assert.False(parser.DataProcessingApproved);
        Assert.Equal(HealthParserProviders.OpenAiModel, parser.EffectiveModel);
        Assert.Equal(HealthParserProviders.OpenAiBaseUrl, parser.EffectiveBaseUrl);
        Assert.Equal(25, parser.TimeoutSeconds);
        Assert.Equal(2048, parser.MaxOutputTokens);
        Assert.Equal(1000, parser.DailyBudget);
        Assert.False(ranking.Enabled);
        Assert.Equal(10, ranking.TimeoutSeconds);
        Assert.Equal(1536, ranking.MaxOutputTokens);
        Assert.Equal(12, ranking.MaxCandidateSets);
        Assert.False(grounding.Enabled);
        Assert.False(grounding.AllowNonMedicalReference);
        Assert.Equal(5, grounding.TopK);
        Assert.False(knowledge.Enabled);
    }

    [Fact]
    public void Gemini_profile_uses_its_own_model_and_url_defaults_and_respects_explicit_limits()
    {
        using var services = Build(new()
        {
            ["HealthParser:Enabled"] = "true",
            ["HealthParser:Provider"] = "Gemini",
            ["HealthParser:DataProcessingApproved"] = "true",
            ["HealthParser:ApiKey"] = new string('x', 32),
            ["HealthParser:TimeoutSeconds"] = "12",
            ["HealthParser:MaxOutputTokens"] = "1024"
        });

        var parser = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;

        Assert.Equal(HealthParserProviders.GeminiModel, parser.EffectiveModel);
        Assert.Equal(HealthParserProviders.GeminiBaseUrl, parser.EffectiveBaseUrl);
        Assert.Equal(12, parser.TimeoutSeconds);
        Assert.Equal(1024, parser.MaxOutputTokens);
    }

    [Theory]
    [InlineData(null, null, HealthParserProviders.GeminiModel)]
    [InlineData(HealthParserProviders.GeminiFlashModel, null, HealthParserProviders.GeminiFlashModel)]
    [InlineData(HealthParserProviders.GeminiFlashModel, HealthParserProviders.GeminiModel, HealthParserProviders.GeminiModel)]
    public void Knowledge_model_preserves_explicit_override_then_ranking_then_service_default(
        string? ranking, string? knowledge, string expected)
    {
        using var services = Build(new()
        {
            ["MealRanking:Model"] = ranking,
            ["NutritionKnowledgeAi:Model"] = knowledge
        });

        Assert.Equal(expected, services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value.Model);
    }

    [Theory]
    [InlineData("HealthParser")]
    [InlineData("MealRanking")]
    [InlineData("NutritionKnowledgeAi")]
    public void Enabling_an_ai_feature_still_requires_processing_approval(string section)
    {
        using var services = Build(new()
        {
            [$"{section}:Enabled"] = "true",
            [$"{section}:ApiKey"] = new string('x', 32),
            [$"{section}:DataProcessingApproved"] = "false"
        });

        Assert.Throws<OptionsValidationException>(() =>
        {
            if (section == "HealthParser") _ = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
            else if (section == "MealRanking") _ = services.GetRequiredService<IOptions<MealRankingOptions>>().Value;
            else _ = services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value;
        });
    }

    private static ServiceProvider Build(Dictionary<string, string?>? values = null)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(values ?? new()).Build();
        return new ServiceCollection().AddNutritionOptions(configuration, new TestEnvironment()).BuildServiceProvider();
    }

    [Theory]
    [InlineData("Gemini", "")]
    [InlineData("Gemini", "explicit-fixture-key-for-this-feature")]
    [InlineData("OpenAI", "explicit-fixture-key-for-this-feature")]
    public void Ai_keys_use_explicit_value_or_the_existing_gemini_fallback(string provider, string explicitKey)
    {
        const string fallback = "synthetic-gemini-fallback-key-for-tests";
        using var services = Build(new()
        {
            ["HealthParser:Provider"] = provider,
            ["HealthParser:ApiKey"] = fallback,
            ["MealRanking:Enabled"] = "true",
            ["MealRanking:DataProcessingApproved"] = "true",
            ["MealRanking:ApiKey"] = explicitKey,
            ["NutritionKnowledgeAi:Enabled"] = "true",
            ["NutritionKnowledgeAi:DataProcessingApproved"] = "true",
            ["NutritionKnowledgeAi:ApiKey"] = explicitKey
        });

        var expected = string.IsNullOrWhiteSpace(explicitKey) ? fallback : explicitKey;
        Assert.Equal(expected, services.GetRequiredService<IOptions<MealRankingOptions>>().Value.ApiKey);
        Assert.Equal(expected, services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value.ApiKey);
    }

    [Fact]
    public void Openai_health_key_cannot_be_used_as_a_gemini_fallback()
    {
        using var services = Build(new()
        {
            ["HealthParser:Provider"] = "OpenAI",
            ["HealthParser:ApiKey"] = new string('x', 32),
            ["MealRanking:Enabled"] = "true",
            ["MealRanking:DataProcessingApproved"] = "true",
            ["NutritionKnowledgeAi:Enabled"] = "true",
            ["NutritionKnowledgeAi:DataProcessingApproved"] = "true"
        });
        Assert.Throws<OptionsValidationException>(() => services.GetRequiredService<IOptions<MealRankingOptions>>().Value);
        Assert.Throws<OptionsValidationException>(() => services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value);
    }

    private sealed class TestEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;
        public string ApplicationName { get; set; } = "NutritionOptionsTests";
        public string ContentRootPath { get; set; } = Path.GetTempPath();
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
