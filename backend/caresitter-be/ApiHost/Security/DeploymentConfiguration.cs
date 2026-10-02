using System.Net;
using Microsoft.AspNetCore.HttpOverrides;
using ForwardedIpNetwork = Microsoft.AspNetCore.HttpOverrides.IPNetwork;

namespace CareSitter.ApiHost.Security;

internal static class DeploymentConfiguration
{
    public static void ValidatePublicEndpoints(IConfiguration configuration, bool isDevelopment)
    {
        if (isDevelopment) return;

        foreach (var key in new[]
        {
            "ConnectionStrings:CareSitter", "Redis:ConnectionString",
            "Jwt:SecretKey", "Encryption:EncryptionKey",
            "Payments:VNPay:TmnCode", "Payments:VNPay:HashSecret",
            "Smtp:Password", "Cloudinary:ApiSecret"
        })
        {
            var value = configuration[key];
            if (string.IsNullOrWhiteSpace(value) ||
                value.Contains("REPLACE_WITH", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException($"{key} must be configured outside Development.");
        }

        var apiBaseUrl = RequireHttpsUrl(configuration["Public:ApiBaseUrl"], "Public:ApiBaseUrl");
        if (apiBaseUrl.AbsolutePath != "/" || apiBaseUrl.Query.Length > 0 || apiBaseUrl.Fragment.Length > 0)
            throw new InvalidOperationException("Public:ApiBaseUrl must be an HTTPS origin without a path.");

        var origins = ReadValues(configuration, "Cors:AllowedOrigins");
        if (origins.Count == 0)
            throw new InvalidOperationException("Cors:AllowedOrigins must contain an explicit HTTPS origin.");
        foreach (var origin in origins)
        {
            var uri = RequireHttpsUrl(origin, "Cors:AllowedOrigins");
            if (uri.AbsolutePath != "/" || uri.Query.Length > 0 || uri.Fragment.Length > 0 ||
                !string.Equals(origin, uri.GetLeftPart(UriPartial.Authority), StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Cors:AllowedOrigins must contain HTTPS origins without paths or wildcards.");
        }

        var returnUrl = RequireHttpsUrl(configuration["Payments:VNPay:ReturnUrl"], "Payments:VNPay:ReturnUrl");
        var ipnUrl = RequireHttpsUrl(configuration["Payments:VNPay:IpnUrl"], "Payments:VNPay:IpnUrl");
        if (!string.Equals(returnUrl.GetLeftPart(UriPartial.Authority), apiBaseUrl.GetLeftPart(UriPartial.Authority), StringComparison.OrdinalIgnoreCase) ||
            returnUrl.AbsolutePath != "/api/v1/payments/vnpay/return" ||
            !string.Equals(ipnUrl.GetLeftPart(UriPartial.Authority), apiBaseUrl.GetLeftPart(UriPartial.Authority), StringComparison.OrdinalIgnoreCase) ||
            ipnUrl.AbsolutePath != "/api/v1/payments/vnpay/ipn" ||
            returnUrl.Query.Length > 0 || ipnUrl.Query.Length > 0)
            throw new InvalidOperationException("VNPay ReturnUrl and IpnUrl must use Public:ApiBaseUrl with their expected paths.");

        RequireHttpsUrl(configuration["Payments:VNPay:PaymentUrl"], "Payments:VNPay:PaymentUrl");
        RequireHttpsUrl(configuration["Payments:VNPay:QueryUrl"], "Payments:VNPay:QueryUrl");
        RequireHttpsUrl(configuration["Payments:VNPay:CustomerWebUrl"], "Payments:VNPay:CustomerWebUrl");
    }

    private static Uri RequireHttpsUrl(string? value, string key)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) ||
            uri.Scheme != Uri.UriSchemeHttps ||
            string.IsNullOrWhiteSpace(uri.Host) ||
            !string.IsNullOrEmpty(uri.UserInfo))
            throw new InvalidOperationException($"{key} must be an absolute HTTPS URL.");
        return uri;
    }

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
