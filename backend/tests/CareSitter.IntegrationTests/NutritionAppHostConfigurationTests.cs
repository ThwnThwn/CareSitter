using CareSitter.AppHost;
using Microsoft.Extensions.Configuration;

namespace CareSitter.IntegrationTests;

public sealed class NutritionAppHostConfigurationTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "caresitter-apphost-test-" + Guid.NewGuid().ToString("N"));

    private string Prepare(string env)
    {
        Directory.CreateDirectory(Path.Combine(_root, "backend"));
        File.WriteAllText(Path.Combine(_root, "backend/.env"), env);
        var appHost = Path.Combine(_root, "host"); Directory.CreateDirectory(appHost);
        return appHost;
    }

    [Fact]
    public void Duplicate_env_keys_match_api_first_value_and_do_not_modify_process_environment()
    {
        const string key = "NutritionFixture__Value";
        var original = Environment.GetEnvironmentVariable(key);
        var appHost = Prepare("NutritionFixture__Value=first\nNUTRITIONFIXTURE__VALUE=second\nNutritionFixture__Value=third\n");
        using var configuration = new ConfigurationManager();
        LocalConfiguration.Load(configuration, appHost, _root);
        Assert.Equal("first", configuration["NutritionFixture:Value"]);
        Assert.Equal(original, Environment.GetEnvironmentVariable(key));
    }

    [Fact]
    public void Existing_configuration_takes_precedence_over_env_fallback()
    {
        var appHost = Prepare("NutritionFixture__Value=file\nNutritionFixture__Value=duplicate\n");
        using var configuration = new ConfigurationManager();
        configuration["NutritionFixture:Value"] = "injected";
        LocalConfiguration.Load(configuration, appHost, _root);
        Assert.Equal("injected", configuration["NutritionFixture:Value"]);
    }

    [Fact]
    public void Api_port_from_env_overrides_apphost_default()
    {
        var appHost = Prepare("AppHost__ApiPort=5040\n");
        using var configuration = new ConfigurationManager();
        configuration["AppHost:ApiPort"] = "5033";
        LocalConfiguration.Load(configuration, appHost, _root);
        Assert.Equal("5040", configuration["AppHost:ApiPort"]);
    }

    [Fact]
    public void Generated_local_parameters_survive_subsequent_launches()
    {
        var appHost = Prepare("");
        using var first = new ConfigurationManager(); LocalConfiguration.Load(first, appHost, _root);
        using var second = new ConfigurationManager(); LocalConfiguration.Load(second, appHost, _root);
        foreach (var name in new[] { "nutrition-admin-password", "nutrition-runtime-password", "nutrition-gateway-key", "nutrition-people-key" })
        {
            Assert.Equal(64, first[$"Parameters:{name}"]!.Length);
            Assert.Equal(first[$"Parameters:{name}"], second[$"Parameters:{name}"]);
        }
    }

    [Fact]
    public void Shared_server_connection_keeps_server_settings_but_uses_the_nutrition_identity()
    {
        const string source = "Host=localhost;Port=5432;Database=caresitter;Username=admin;Password=main-secret;SSL Mode=Prefer";

        var value = NutritionDatabaseConfiguration.BuildSharedServerConnection(
            source, "nutrition", "nutrition_app", new string('a', 64));
        var connection = new Npgsql.NpgsqlConnectionStringBuilder(value);

        Assert.Equal("localhost", connection.Host);
        Assert.Equal(5432, connection.Port);
        Assert.Equal("nutrition", connection.Database);
        Assert.Equal("nutrition_app", connection.Username);
        Assert.Equal(new string('a', 64), connection.Password);
        Assert.Equal(Npgsql.SslMode.Prefer, connection.SslMode);
        Assert.DoesNotContain("main-secret", value, StringComparison.Ordinal);
    }

    public void Dispose()
    {
        var resolved = Path.GetFullPath(_root);
        var parent = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (!resolved.StartsWith(parent, StringComparison.OrdinalIgnoreCase) ||
            !System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(resolved), "^caresitter-apphost-test-[a-f0-9]{32}$"))
            throw new InvalidOperationException("Unexpected test directory.");
        if (Directory.Exists(resolved)) Directory.Delete(resolved, recursive: true);
    }
}
