using Microsoft.Extensions.Configuration.Json;
using Microsoft.Extensions.Configuration.Memory;

namespace CareSitter.Nutrition.Infrastructure;

internal static class NutritionEnvironmentConfiguration
{
    private static readonly string[] Sections = ["Nutrition", "NutritionCatalog", "MealGrounding", "HealthParser",
        "MealRanking", "NutritionKnowledgeAi", "NutritionKnowledgeCorpus", "Jwt", "Gateway", "People", "Cors", "BeneficiaryEvents"];
    private static readonly HashSet<string> SharedKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "ConnectionStrings:Nutrition", "KAFKA_ENABLED", "KAFKA_FLOW_NUTRITION_ENABLED",
        "KAFKA_BOOTSTRAP_SERVERS", "KAFKA_TOPIC_NUTRITION", "KAFKA_TOPIC_NUTRITION_DLQ"
    };

    public static void LoadEnv(this ConfigurationManager configuration, IHostEnvironment environment)
    {
        var path = configuration["CARESITTER_ENV_FILE"];
        if (!string.IsNullOrWhiteSpace(path) && !File.Exists(path))
            throw new InvalidOperationException("Configured CARESITTER_ENV_FILE does not exist.");
        if (!string.IsNullOrWhiteSpace(path) || environment.IsDevelopment())
        {
            KeyValuePair<string, string?>[] values;
            try
            {
                var entries = string.IsNullOrWhiteSpace(path)
                    ? DotNetEnv.Env.NoEnvVars().TraversePath().Load(Path.Combine(environment.ContentRootPath, ".env"))
                    : DotNetEnv.Env.NoEnvVars().Load(path);
                values = entries
                    .Select(pair => new KeyValuePair<string, string?>(pair.Key.Replace("__", ":"), pair.Value))
                    .Where(pair => SharedKeys.Contains(pair.Key) ||
                        Sections.Any(section => pair.Key.StartsWith(section + ":", StringComparison.OrdinalIgnoreCase)))
                    .GroupBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase)
                    .Select(group => group.First()).ToArray();
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or Sprache.ParseException)
            {
                // Parser diagnostics can include the original line, including credentials.
                throw new InvalidOperationException("Could not read the Nutrition environment file.");
            }

            // File values override public appsettings defaults; injected env, CLI and user secrets remain higher priority.
            var index = 0;
            for (var i = 0; i < configuration.Sources.Count; i++)
                if (configuration.Sources[i] is JsonConfigurationSource json && json.Path is { } jsonPath &&
                    Path.GetFileName(jsonPath).StartsWith("appsettings", StringComparison.OrdinalIgnoreCase))
                    index = i + 1;
            configuration.Sources.Insert(index, new MemoryConfigurationSource { InitialData = values });
        }

        // Accept the existing shared Kafka names without AppHost translating each setting.
        var kafkaEnabled = configuration.GetValue<bool>("KAFKA_ENABLED") &&
            configuration.GetValue<bool>("KAFKA_FLOW_NUTRITION_ENABLED");
        configuration.Sources.Insert(0, new MemoryConfigurationSource
        {
            InitialData = new Dictionary<string, string?>
            {
                ["BeneficiaryEvents:Enabled"] = kafkaEnabled.ToString(),
                ["BeneficiaryEvents:BootstrapServers"] = configuration["KAFKA_BOOTSTRAP_SERVERS"],
                ["BeneficiaryEvents:Topic"] = configuration["KAFKA_TOPIC_NUTRITION"] ?? "caresitter.nutrition.events.v1",
                ["BeneficiaryEvents:ConsumerGroup"] = "nutrition-beneficiary-deletion-v1",
                ["BeneficiaryEvents:DlqTopic"] = configuration["KAFKA_TOPIC_NUTRITION_DLQ"] ?? "caresitter.nutrition.events.v1.dlq"
            }
        });
    }
}
