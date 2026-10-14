using System.Net;
using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using CareSitter.ApiHost.Nutrition;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CareSitter.IntegrationTests;

public sealed class InternalCertificateTrustTests
{
    [Fact]
    public void Private_ca_keeps_hostname_expiry_purpose_and_chain_checks()
    {
        using var fixture = new Certificates();
        using var handler = InternalCertificateTrust.CreateHandler(fixture.RootPath);
        var validate = handler.ServerCertificateCustomValidationCallback!;
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://localhost/");
        using var valid = fixture.Leaf();
        Assert.True(validate(request, valid, null, SslPolicyErrors.RemoteCertificateChainErrors));
        Assert.False(validate(request, valid, null, SslPolicyErrors.RemoteCertificateNameMismatch));
        Assert.False(validate(request, null, null, SslPolicyErrors.RemoteCertificateNotAvailable));
        using var expired = fixture.Leaf(expired: true);
        Assert.False(validate(request, expired, null, SslPolicyErrors.RemoteCertificateChainErrors));
        using var wrongPurpose = fixture.Leaf(serverAuth: false);
        Assert.False(validate(request, wrongPurpose, null, SslPolicyErrors.RemoteCertificateChainErrors));
        using var other = new Certificates();
        using var unrelated = other.Leaf();
        Assert.False(validate(request, unrelated, null, SslPolicyErrors.RemoteCertificateChainErrors));
    }

    [Fact]
    public void Missing_or_non_ca_trust_file_fails_closed_and_default_keeps_system_trust()
    {
        using var fixture = new Certificates();
        Assert.Throws<InvalidOperationException>(() => InternalCertificateTrust.CreateHandler(Path.Combine(fixture.DirectoryPath, "missing.pem")));
        using var leaf = fixture.Leaf();
        File.WriteAllText(fixture.LeafPath, leaf.ExportCertificatePem());
        Assert.Throws<InvalidOperationException>(() => InternalCertificateTrust.CreateHandler(fixture.LeafPath));
        using var standard = InternalCertificateTrust.CreateHandler(null);
        Assert.Null(standard.ServerCertificateCustomValidationCallback);
    }

    [Fact]
    public async Task Actual_tls_http2_accepts_our_ca_and_rejects_a_different_ca()
    {
        using var certificates = new Certificates();
        using var serverCertificate = certificates.Leaf();
        using var host = await new HostBuilder().ConfigureWebHost(web => web.UseKestrel(options =>
            options.Listen(IPAddress.Loopback, 0, endpoint =>
            {
                endpoint.Protocols = HttpProtocols.Http2;
                endpoint.UseHttps(serverCertificate);
            })).Configure(app => app.Run(async context => await context.Response.WriteAsync("healthy")))).StartAsync();
        var address = host.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
        using var handler = InternalCertificateTrust.CreateHandler(certificates.RootPath);
        using var client = new HttpClient(handler);
        using var request = new HttpRequestMessage(HttpMethod.Get, address)
        {
            Version = HttpVersion.Version20, VersionPolicy = HttpVersionPolicy.RequestVersionExact
        };
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpVersion.Version20, response.Version);
        Assert.Equal("healthy", await response.Content.ReadAsStringAsync());
        using var other = new Certificates();
        using var wrongHandler = InternalCertificateTrust.CreateHandler(other.RootPath);
        using var wrongClient = new HttpClient(wrongHandler);
        await Assert.ThrowsAsync<HttpRequestException>(() => wrongClient.GetAsync(address));
        await host.StopAsync();
    }

    internal sealed class Certificates : IDisposable
    {
        public string DirectoryPath { get; } = Path.Combine(Path.GetTempPath(), "caresitter-tls-" + Guid.NewGuid().ToString("N"));
        public string RootPath => Path.Combine(DirectoryPath, "ca.pem");
        public string LeafPath => Path.Combine(DirectoryPath, "leaf.pem");
        private readonly RSA _rootKey = RSA.Create(2048);
        private readonly X509Certificate2 _root;

        public Certificates()
        {
            Directory.CreateDirectory(DirectoryPath);
            var request = new CertificateRequest("CN=CareSitter Test Root", _rootKey, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
            request.CertificateExtensions.Add(new X509BasicConstraintsExtension(true, false, 0, true));
            request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.KeyCertSign, true));
            _root = request.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-5), DateTimeOffset.UtcNow.AddDays(5));
            File.WriteAllText(RootPath, _root.ExportCertificatePem());
        }

        public X509Certificate2 Leaf(bool expired = false, bool serverAuth = true)
        {
            using var key = RSA.Create(2048);
            var request = new CertificateRequest("CN=localhost", key, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
            request.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
            request.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension(
                new OidCollection { new(serverAuth ? "1.3.6.1.5.5.7.3.1" : "1.3.6.1.5.5.7.3.2") }, true));
            var names = new SubjectAlternativeNameBuilder();
            names.AddDnsName("localhost"); names.AddIpAddress(IPAddress.Loopback);
            request.CertificateExtensions.Add(names.Build());
            using var publicCertificate = request.Create(_root, DateTimeOffset.UtcNow.AddDays(-3),
                DateTimeOffset.UtcNow.AddDays(expired ? -1 : 2), RandomNumberGenerator.GetBytes(16));
            using var withKey = publicCertificate.CopyWithPrivateKey(key);
            return new X509Certificate2(withKey.Export(X509ContentType.Pfx));
        }

        public void Dispose()
        {
            _root.Dispose(); _rootKey.Dispose();
            File.Delete(RootPath); File.Delete(LeafPath);
            Directory.Delete(DirectoryPath);
        }
    }
}
