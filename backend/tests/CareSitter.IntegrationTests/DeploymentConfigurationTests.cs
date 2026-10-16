using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Configuration;
using CareSitter.ApiHost.Security;

namespace CareSitter.IntegrationTests;

public sealed class DeploymentConfigurationTests
{
    [Fact]
    public void Non_development_requires_https_public_urls_and_exact_vnpay_callback_paths()
    {
        var values = new Dictionary<string, string?>
        {
            ["ConnectionStrings:CareSitter"] = "Host=db;Database=caresitter;Password=sample",
            ["Redis:ConnectionString"] = "redis:6379,password=sample",
            ["Jwt:SecretKey"] = "test-only-key-with-at-least-thirty-two-characters",
            ["Encryption:EncryptionKey"] = "test-only-key-with-at-least-thirty-two-characters",
            ["Payments:VNPay:TmnCode"] = "test-tmn",
            ["Payments:VNPay:HashSecret"] = "test-hash",
            ["Smtp:Password"] = "test-app-password",
            ["Cloudinary:ApiSecret"] = "test-cloudinary-secret",
            ["Public:ApiBaseUrl"] = "https://admin.example.com",
            ["Cors:AllowedOrigins:0"] = "https://admin.example.com",
            ["Payments:VNPay:ReturnUrl"] = "https://admin.example.com/api/v1/payments/vnpay/return",
            ["Payments:VNPay:IpnUrl"] = "https://admin.example.com/api/v1/payments/vnpay/ipn",
            ["Payments:VNPay:PaymentUrl"] = "https://payments.example.com/pay",
            ["Payments:VNPay:QueryUrl"] = "https://payments.example.com/query",
            ["Payments:VNPay:CustomerWebUrl"] = "https://customer.example.com"
        };

        DeploymentConfiguration.ValidatePublicEndpoints(Configuration(values), isDevelopment: false);

        values["Payments:PayOS:Enabled"] = "true";
        values["Payments:PayOS:CustomerWebUrl"] = "http://localhost:55709";
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.ValidatePublicEndpoints(Configuration(values), isDevelopment: false));
        values["Payments:PayOS:CustomerWebUrl"] = "https://customer.example.com";
        DeploymentConfiguration.ValidatePublicEndpoints(Configuration(values), isDevelopment: false);

        values["Cors:AllowedOrigins:0"] = "http://admin.example.com";
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.ValidatePublicEndpoints(Configuration(values), isDevelopment: false));

        values["Payments:VNPay:IpnUrl"] = "https://admin.example.com/api/v1/payments/vnpay/ipn";
        values["Jwt:SecretKey"] = "REPLACE_WITH_RANDOM_JWT_SECRET_AT_LEAST_32_CHARACTERS";
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.ValidatePublicEndpoints(Configuration(values), isDevelopment: false));

        values["Cors:AllowedOrigins:0"] = "https://admin.example.com";
        values["Jwt:SecretKey"] = "test-only-key-with-at-least-thirty-two-characters";
        values["Payments:VNPay:IpnUrl"] = "https://other.example.com/api/v1/payments/vnpay/ipn";
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.ValidatePublicEndpoints(Configuration(values), isDevelopment: false));
    }

    [Fact]
    public void Production_requires_an_explicit_trusted_proxy()
    {
        var configuration = Configuration();

        var exception = Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.CreateForwardedHeadersOptions(configuration, isProduction: true));

        Assert.Contains("Proxy:KnownProxies", exception.Message);
    }

    [Fact]
    public void Forwarded_headers_trust_only_configured_proxies_and_networks()
    {
        var configuration = Configuration(new Dictionary<string, string?>
        {
            ["Proxy:KnownProxies:0"] = "10.0.0.4",
            ["Proxy:KnownNetworks:0"] = "10.20.0.0/16",
            ["Proxy:ForwardLimit"] = "2"
        });

        var options = DeploymentConfiguration.CreateForwardedHeadersOptions(configuration, isProduction: true);

        Assert.Equal(ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
            options.ForwardedHeaders);
        Assert.Equal(2, options.ForwardLimit);
        Assert.Equal(new[] { "10.0.0.4" }, options.KnownProxies.Select(proxy => proxy.ToString()));
        var network = Assert.Single(options.KnownNetworks);
        Assert.Equal("10.20.0.0", network.Prefix.ToString());
        Assert.Equal(16, network.PrefixLength);
    }

    [Theory]
    [InlineData("invalid")]
    [InlineData("10.0.0.0/99")]
    public void Invalid_proxy_configuration_fails_fast(string invalidValue)
    {
        var configuration = Configuration(new Dictionary<string, string?>
        {
            ["Proxy:KnownNetworks:0"] = invalidValue
        });

        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.CreateForwardedHeadersOptions(configuration, isProduction: false));
    }

    [Fact]
    public void Production_requires_durable_hangfire_storage()
    {
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.UsePostgresHangfire(Configuration(), isProduction: true));

        var disabled = Configuration(new Dictionary<string, string?>
        {
            ["HANGFIRE_USE_POSTGRES"] = "false",
            ["ConnectionStrings:CareSitter"] = "Host=localhost;Database=caresitter"
        });
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.UsePostgresHangfire(disabled, isProduction: true));

        var missingConnection = Configuration(new Dictionary<string, string?>
        {
            ["HANGFIRE_USE_POSTGRES"] = "true"
        });
        var exception = Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.UsePostgresHangfire(missingConnection, isProduction: true));
        Assert.Contains("ConnectionStrings:CareSitter", exception.Message);
    }

    [Fact]
    public void Postgres_hangfire_requires_a_connection_string_in_every_environment()
    {
        var configuration = Configuration(new Dictionary<string, string?>
        {
            ["HANGFIRE_USE_POSTGRES"] = "true"
        });

        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.UsePostgresHangfire(configuration, isProduction: false));
    }

    [Fact]
    public void Development_can_use_in_memory_hangfire_and_explicit_postgres_storage()
    {
        Assert.False(DeploymentConfiguration.UsePostgresHangfire(
            Configuration(), isProduction: false));

        var persistent = Configuration(new Dictionary<string, string?>
        {
            ["HANGFIRE_USE_POSTGRES"] = "true",
            ["ConnectionStrings:CareSitter"] = "Host=localhost;Database=caresitter"
        });
        Assert.True(DeploymentConfiguration.UsePostgresHangfire(persistent, isProduction: false));

        Assert.True(DeploymentConfiguration.UsePostgresHangfire(persistent, isProduction: true));
    }

    private static IConfiguration Configuration(IDictionary<string, string?>? overrides = null)
    {
        var values = new Dictionary<string, string?>();
        if (overrides is not null)
        {
            foreach (var pair in overrides)
                values[pair.Key] = pair.Value;
        }

        return new ConfigurationBuilder().AddInMemoryCollection(values).Build();
    }
}
