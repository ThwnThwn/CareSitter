using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Support.Infrastructure.Diagnostics;

public interface ICrashQueryTokenProvider
{
    Task<string> GetAsync(CancellationToken ct);
}
internal sealed class CrashQueryTokenProvider(IOptions<CrashReportOptions> options) : ICrashQueryTokenProvider
{
    private readonly Lazy<GoogleCredential> _credential = new(() =>
        (string.IsNullOrWhiteSpace(options.Value.ServiceAccountPath)
            ? GoogleCredential.GetApplicationDefault()
            : GoogleCredential.FromFile(options.Value.ServiceAccountPath))
        .CreateScoped("https://www.googleapis.com/auth/bigquery"));
    public Task<string> GetAsync(CancellationToken ct) =>
        _credential.Value.UnderlyingCredential.GetAccessTokenForRequestAsync(cancellationToken: ct);
}
