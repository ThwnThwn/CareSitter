using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class NutritionEnvironmentConfigurationTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "nutrition-env-test-" + Guid.NewGuid().ToString("N"));

    private string WriteEnv(string contents)
    {
        Directory.CreateDirectory(_root);
        var path = Path.Combine(_root, ".env");
        File.WriteAllText(path, contents);
        return path;
    }

    private ConfigurationManager Load(string contents, string environment = "Production")
    {
        var configuration = new ConfigurationManager();
        configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["CARESITTER_ENV_FILE"] = WriteEnv(contents) });
        configuration.LoadEnv(new TestEnvironment(environment, _root));
        return configuration;
    }

    [Fact]
    public void Loads_owned_values_without_importing_api_credentials_or_modifying_process_environment()
    {
        var previous = Environment.GetEnvironmentVariable("HealthParser__ApiKey");
        using var configuration = Load("HealthParser__ApiKey=synthetic-fixture-key\n" +
            "MealRanking__TimeoutSeconds=12\nConnectionStrings__Nutrition=fixture-nutrition-db\n" +
            "ConnectionStrings__CareSitter=excluded-core-db\nPayments__PayOS__ApiKey=excluded-payment-key\nSmtp__Password=excluded-mail-password\n");

        Assert.Equal("synthetic-fixture-key", configuration["HealthParser:ApiKey"]);
        Assert.Equal("12", configuration["MealRanking:TimeoutSeconds"]);
        Assert.Equal("fixture-nutrition-db", configuration.GetConnectionString("Nutrition"));
        Assert.Null(configuration.GetConnectionString("CareSitter"));
        Assert.Null(configuration["Payments:PayOS:ApiKey"]);
        Assert.Null(configuration["Smtp:Password"]);
        Assert.Equal(previous, Environment.GetEnvironmentVariable("HealthParser__ApiKey"));
    }

    [Fact]
    public void File_overrides_public_defaults_but_environment_and_command_line_keep_priority()
    {
        var file = WriteEnv("MealRanking__TimeoutSeconds=12\nMealRanking__MaxOutputTokens=1536\nMealRanking__MaxAttempts=2\n");
        var defaults = Path.Combine(_root, "appsettings.json");
        File.WriteAllText(defaults, "{\"MealRanking\":{\"TimeoutSeconds\":10,\"MaxOutputTokens\":256,\"MaxAttempts\":1}}");
        var prefix = "NUTRITION_ENV_FIXTURE_" + Guid.NewGuid().ToString("N") + "_";
        var variable = prefix + "MealRanking__MaxOutputTokens";
        Environment.SetEnvironmentVariable(variable, "2048");
        try
        {
            using var configuration = new ConfigurationManager();
            configuration.AddJsonFile(defaults, optional: false);
            configuration.AddEnvironmentVariables(prefix);
            configuration.AddCommandLine(["--MealRanking:MaxAttempts=1"]);
            configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["CARESITTER_ENV_FILE"] = file });

            configuration.LoadEnv(new TestEnvironment(Environments.Production, _root));

            Assert.Equal("12", configuration["MealRanking:TimeoutSeconds"]);
            Assert.Equal("2048", configuration["MealRanking:MaxOutputTokens"]);
            Assert.Equal("1", configuration["MealRanking:MaxAttempts"]);
        }
        finally { Environment.SetEnvironmentVariable(variable, null); }
    }

    [Fact]
    public void Duplicate_keys_match_the_first_value_used_by_api_and_apphost()
    {
        using var configuration = Load("HealthParser__Provider=Gemini\nHEALTHPARSER__PROVIDER=OpenAI\nHealthParser__Provider=OpenAI\n");
        Assert.Equal("Gemini", configuration["HealthParser:Provider"]);
    }

    [Theory]
    [InlineData("Development", true)]
    [InlineData("Staging", false)]
    [InlineData("Production", false)]
    public void Only_development_discovers_a_parent_env_file(string environment, bool expected)
    {
        WriteEnv("Nutrition__Enabled=true\n");
        var contentRoot = Path.Combine(_root, "service", "app");
        Directory.CreateDirectory(contentRoot);
        using var configuration = new ConfigurationManager();

        configuration.LoadEnv(new TestEnvironment(environment, contentRoot));

        Assert.Equal(expected, configuration.GetValue<bool>("Nutrition:Enabled"));
    }

    [Fact]
    public void Missing_explicit_file_fails_instead_of_silently_using_another_file()
    {
        WriteEnv("Nutrition__Enabled=true\n");
        using var configuration = new ConfigurationManager();
        configuration["CARESITTER_ENV_FILE"] = Path.Combine(_root, "missing.env");
        Assert.Throws<InvalidOperationException>(() => configuration.LoadEnv(new TestEnvironment(Environments.Development, _root)));
    }

    [Theory]
    [InlineData(true, true, true)]
    [InlineData(false, true, false)]
    [InlineData(true, false, false)]
    public void Shared_kafka_names_require_both_feature_flags(bool kafka, bool flow, bool expected)
    {
        using var configuration = Load($"KAFKA_ENABLED={kafka}\nKAFKA_FLOW_NUTRITION_ENABLED={flow}\n" +
            "KAFKA_BOOTSTRAP_SERVERS=fixture.invalid:9092\nKAFKA_TOPIC_NUTRITION=fixture.nutrition\n");

        Assert.Equal(expected, configuration.GetValue<bool>("BeneficiaryEvents:Enabled"));
        Assert.Equal("fixture.invalid:9092", configuration["BeneficiaryEvents:BootstrapServers"]);
        Assert.Equal("fixture.nutrition", configuration["BeneficiaryEvents:Topic"]);
        Assert.Equal("nutrition-beneficiary-deletion-v1", configuration["BeneficiaryEvents:ConsumerGroup"]);
    }

    [Fact]
    public void Parse_errors_do_not_include_the_original_credential_line()
    {
        using var configuration = new ConfigurationManager();
        configuration["CARESITTER_ENV_FILE"] = WriteEnv("HealthParser__ApiKey=synthetic-sensitive-value\ninvalid line!\n");

        var error = Assert.Throws<InvalidOperationException>(() =>
            configuration.LoadEnv(new TestEnvironment(Environments.Production, _root)));

        Assert.Null(error.InnerException);
        Assert.DoesNotContain("synthetic-sensitive-value", error.ToString(), StringComparison.Ordinal);
    }

    [Fact]
    public void Explicit_service_kafka_configuration_overrides_shared_aliases()
    {
        using var configuration = Load("KAFKA_ENABLED=true\nKAFKA_FLOW_NUTRITION_ENABLED=true\n" +
            "BeneficiaryEvents__Enabled=false\nBeneficiaryEvents__Topic=explicit.topic\n");
        Assert.False(configuration.GetValue<bool>("BeneficiaryEvents:Enabled"));
        Assert.Equal("explicit.topic", configuration["BeneficiaryEvents:Topic"]);
    }

    [Fact]
    public void Having_an_api_key_does_not_enable_ai_or_approve_processing()
    {
        using var configuration = Load("HealthParser__Provider=Gemini\nHealthParser__ApiKey=synthetic-key-for-disabled-feature\n");
        using var services = new ServiceCollection()
            .AddNutritionOptions(configuration, new TestEnvironment(Environments.Production, _root)).BuildServiceProvider();

        var parser = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
        Assert.False(parser.Enabled);
        Assert.False(parser.DataProcessingApproved);
        Assert.False(services.GetRequiredService<IOptions<MealRankingOptions>>().Value.Enabled);
        Assert.False(services.GetRequiredService<IOptions<KnowledgeAnswerAiOptions>>().Value.Enabled);
    }

    public void Dispose()
    {
        var resolved = Path.GetFullPath(_root);
        var parent = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (!resolved.StartsWith(parent, StringComparison.OrdinalIgnoreCase) ||
            !System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(resolved), "^nutrition-env-test-[a-f0-9]{32}$"))
            throw new InvalidOperationException("Unexpected test directory.");
        if (Directory.Exists(resolved)) Directory.Delete(resolved, recursive: true);
    }

    private sealed class TestEnvironment(string name, string root) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "NutritionEnvTests";
        public string ContentRootPath { get; set; } = root;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
