using System.Security.Cryptography;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Configuration;

namespace CareSitter.AppHost;

internal static class LocalConfiguration
{
    private static readonly HashSet<string> EnvironmentOverrides = new(StringComparer.OrdinalIgnoreCase)
    {
        "AppHost:ApiPort"
    };

    public static string Load(IConfigurationManager configuration, string appHostDirectory, string repository)
    {
        var envPath = Path.GetFullPath(configuration["AppHost:ApiEnvFile"] ?? Path.Combine(repository, "backend/.env"));
        if (File.Exists(envPath))
        {
            // Parse only: do not expose every API credential in the AppHost/other services' process environment.
            // The API port is an explicit AppHost override; other .env values remain fallbacks.
            var fallback = DotNetEnv.Env.NoEnvVars().Load(envPath)
                .Select(pair => new KeyValuePair<string, string?>(pair.Key.Replace("__", ":"), pair.Value))
                // ApiHost uses NoClobber: the first occurrence wins, including normalized/case-insensitive keys.
                .GroupBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase).Select(group => group.First())
                .Where(pair => EnvironmentOverrides.Contains(pair.Key) || configuration[pair.Key] is null).ToArray();
            configuration.AddInMemoryCollection(fallback);
        }

        var localPath = Path.Combine(appHostDirectory, "appsettings.Development.Local.json");
        var local = File.Exists(localPath) ? JsonNode.Parse(File.ReadAllText(localPath))!.AsObject() : new JsonObject();
        var parameters = local["Parameters"] as JsonObject ?? new JsonObject();
        local["Parameters"] = parameters;
        var changed = false;
        foreach (var name in new[] { "nutrition-admin-password", "nutrition-runtime-password", "nutrition-gateway-key", "nutrition-people-key" })
        {
            if (!string.IsNullOrEmpty(configuration[$"Parameters:{name}"]) || parameters[name] is not null) continue;
            parameters[name] = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)); changed = true;
        }
        if (changed)
        {
            var temporary = localPath + ".tmp";
            File.WriteAllText(temporary, local.ToJsonString(new() { WriteIndented = true }));
            File.Move(temporary, localPath, overwrite: true);
        }
        configuration.AddJsonFile(localPath, optional: false, reloadOnChange: false);
        configuration.AddEnvironmentVariables();
        return envPath;
    }
}
