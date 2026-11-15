using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace CareSitter.Nutrition.Infrastructure;

/// <summary>Trusts only the configured internal CA while retaining hostname, expiry and EKU checks.</summary>
internal static class InternalCertificateTrust
{
    public static HttpClientHandler CreateHandler(string? certificatePath)
    {
        var handler = new HttpClientHandler();
        if (string.IsNullOrWhiteSpace(certificatePath)) return handler;
        byte[] rootBytes;
        try
        {
            using var root = new X509Certificate2(certificatePath);
            if (root.HasPrivateKey || !root.Extensions.OfType<X509BasicConstraintsExtension>().Any(e => e.CertificateAuthority))
                throw new CryptographicException();
            rootBytes = root.RawData;
        }
        catch (Exception exception) when (exception is IOException or CryptographicException)
        {
            handler.Dispose();
            throw new InvalidOperationException("The internal TLS root must be a readable CA certificate without a private key.");
        }
        handler.ServerCertificateCustomValidationCallback = (_, certificate, remoteChain, errors) =>
        {
            if (certificate is null || (errors & (SslPolicyErrors.RemoteCertificateNameMismatch |
                    SslPolicyErrors.RemoteCertificateNotAvailable)) != SslPolicyErrors.None) return false;
            using var root = new X509Certificate2(rootBytes);
            using var chain = new X509Chain();
            chain.ChainPolicy.TrustMode = X509ChainTrustMode.CustomRootTrust;
            chain.ChainPolicy.CustomTrustStore.Add(root);
            // These short-lived private certificates have no public CRL/OCSP endpoint.
            chain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
            chain.ChainPolicy.VerificationFlags = X509VerificationFlags.NoFlag;
            chain.ChainPolicy.ApplicationPolicy.Add(new Oid("1.3.6.1.5.5.7.3.1"));
            if (remoteChain is not null)
                foreach (var element in remoteChain.ChainElements) chain.ChainPolicy.ExtraStore.Add(element.Certificate);
            return chain.Build(certificate);
        };
        return handler;
    }
}
