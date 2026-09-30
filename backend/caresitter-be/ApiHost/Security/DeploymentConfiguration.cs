using System.Net;
using Microsoft.AspNetCore.HttpOverrides;
using ForwardedIpNetwork = Microsoft.AspNetCore.HttpOverrides.IPNetwork;

namespace CareSitter.ApiHost.Security;

internal static class DeploymentConfiguration
{
    public static ForwardedHeadersOptions CreateForwardedHeadersOptions(
        IConfiguration configuration,
        bool isProduction)
    {
        var proxyAddresses = ReadValues(configuration, "Proxy:KnownProxies");
        var proxyNetworks = ReadValues(configuration, "Proxy:KnownNetworks");

        if (isProduction && proxyAddresses.Count == 0 && proxyNetworks.Count == 0)
        {
            throw new InvalidOperationException(
                "Production requires at least one trusted reverse proxy in " +
                "Proxy:KnownProxies or Proxy:KnownNetworks.");
        }

        var options = new ForwardedHeadersOptions
        {
            ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
            ForwardLimit = configuration.GetValue<int?>("Proxy:ForwardLimit") ?? 1
        };
        if (options.ForwardLimit < 1)
            throw new InvalidOperationException("Proxy:ForwardLimit must be at least 1.");

        // Replace framework defaults so the accepted proxy list is entirely explicit.
        options.KnownProxies.Clear();
        options.KnownNetworks.Clear();

        foreach (var value in proxyAddresses)
        {
            if (!IPAddress.TryParse(value, out var address))
                throw new InvalidOperationException($"Invalid IP address in Proxy:KnownProxies: '{value}'.");
            options.KnownProxies.Add(address);
        }

        foreach (var value in proxyNetworks)
        {
            if (!ForwardedIpNetwork.TryParse(value.AsSpan(), out var network))
                throw new InvalidOperationException($"Invalid CIDR network in Proxy:KnownNetworks: '{value}'.");
            options.KnownNetworks.Add(network);
        }

        return options;
    }

    public static bool UsePostgresHangfire(
        IConfiguration configuration,
        bool isProduction)
    {
        var setting = configuration["HANGFIRE_USE_POSTGRES"];
        var connectionString = configuration.GetConnectionString("CareSitter");

        if (isProduction)
        {
            if (!string.Equals(setting, "true", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Production requires HANGFIRE_USE_POSTGRES=true. InMemory Hangfire storage is not durable.");
            }

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new InvalidOperationException(
                    "Production requires ConnectionStrings:CareSitter for Hangfire PostgreSQL storage.");
            }
        }

        if (string.Equals(setting, "true", StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new InvalidOperationException(
                    "HANGFIRE_USE_POSTGRES=true requires ConnectionStrings:CareSitter.");
            }

            return true;
        }

        return false;
    }

    private static List<string> ReadValues(IConfiguration configuration, string key) =>
        configuration.GetSection(key).GetChildren()
            .Select(child => child.Value?.Trim())
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value!)
            .ToList();
}
